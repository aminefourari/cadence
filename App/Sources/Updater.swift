import AppKit
import Foundation

/// In-app updates from GitHub Releases.
///
/// Every installed copy checks `releases/latest` of the repository named by
/// `CadenceUpdateRepository` in Info.plist at launch and every few hours. A newer
/// release is downloaded and verified in the background (bundle id, version,
/// Developer ID signature from team T7A3N2UXYN), then installed automatically as soon as nothing would be
/// interrupted (`isIdle`), or when the app quits. Automatic install can be turned off;
/// the update is then offered in Preferences → Updates.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    struct Release: Equatable {
        let version: String
        let notes: String
        let assetURL: URL
        let pageURL: URL
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(Release)
        /// Downloaded and verified; waiting for a quiet moment (or quit) to install.
        case ready(Release)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var installAutomatically: Bool {
        didSet { UserDefaults.standard.set(installAutomatically, forKey: Self.autoInstallKey) }
    }

    /// Set by the app: true when restarting now would interrupt nothing.
    var isIdle: () -> Bool = { true }

    var hasUpdate: Bool {
        switch state {
        case .available, .downloading, .ready: return true
        default: return false
        }
    }

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private let repository = Bundle.main.object(forInfoDictionaryKey: "CadenceUpdateRepository") as? String
        ?? "aminefourari/cadence"
    private static let autoInstallKey = "cadence.installUpdatesAutomatically"
    private static let checkInterval: TimeInterval = 4 * 3600
    private var stagedApp: URL?
    private var timers: [Timer] = []

    var releasesPage: URL { URL(string: "https://github.com/\(repository)/releases")! }

    private init() {
        installAutomatically = UserDefaults.standard.object(forKey: Self.autoInstallKey) as? Bool ?? true
    }

    /// Starts background checks: now, then every few hours; and an idle watcher that
    /// installs a staged update at the first quiet moment.
    func startAutomaticUpdates() {
        guard timers.isEmpty else { return }
        Task { await checkAndStage() }
        let check = Timer(timeInterval: Self.checkInterval, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.checkAndStage() }
        }
        let idle = Timer(timeInterval: 60, repeats: true) { _ in
            Task { @MainActor in Updater.shared.installIfIdle() }
        }
        for timer in [check, idle] { RunLoop.main.add(timer, forMode: .common) }
        timers = [check, idle]
    }

    private func checkAndStage() async {
        if case .ready = state { return }
        await check()
        guard installAutomatically, case .available(let release) = state else { return }
        await download(release)
        installIfIdle()
    }

    func check() async {
        switch state {
        case .checking, .downloading, .ready, .installing: return
        default: break
        }
        state = .checking
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Cadence-Updater", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError("GitHub didn't return a release.")
            }
            let payload = try JSONDecoder().decode(GitHubRelease.self, from: data)

            let version = payload.tagName.hasPrefix("v") ? String(payload.tagName.dropFirst()) : payload.tagName
            guard Self.isNewer(version, than: currentVersion) else {
                state = .upToDate
                return
            }
            guard let asset = payload.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
                throw UpdateError("Release \(version) has no app download.")
            }
            state = .available(Release(
                version: version,
                notes: payload.body ?? "",
                assetURL: asset.browserDownloadURL,
                pageURL: payload.htmlURL
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Installs now (user clicked): downloads if needed, then swaps and relaunches.
    func install(_ release: Release) async {
        if stagedApp == nil { await download(release) }
        guard case .ready = state else { return }
        apply(relaunch: true)
    }

    /// Downloads and verifies the release into a temporary folder.
    private func download(_ release: Release) async {
        state = .downloading(release)
        do {
            let parent = Bundle.main.bundleURL.deletingLastPathComponent()
            guard FileManager.default.isWritableFile(atPath: parent.path) else {
                throw UpdateError("Cadence can't write to \(parent.path). Download the update from GitHub instead.")
            }

            let (download, _) = try await URLSession.shared.download(from: release.assetURL)
            let work = FileManager.default.temporaryDirectory
                .appendingPathComponent("cadence-update-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let zip = work.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: download, to: zip)
            try await Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path])

            let newApp = work.appendingPathComponent("Cadence.app")
            guard let bundle = Bundle(url: newApp),
                  bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw UpdateError("The download isn't a Cadence app.")
            }
            let newVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            guard newVersion == release.version else {
                throw UpdateError("The download is version \(newVersion), expected \(release.version).")
            }
            // Releases are Developer ID signed + notarized by the release workflow; refuse anything else.
            try await Self.run("/usr/bin/codesign", [
                "--verify", "--deep", "--strict",
                "-R=anchor apple generic and certificate leaf[subject.OU] = \"T7A3N2UXYN\"",
                newApp.path,
            ])

            stagedApp = newApp
            state = .ready(release)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func installIfIdle() {
        guard installAutomatically, case .ready = state, isIdle() else { return }
        apply(relaunch: true)
    }

    /// Called when the app quits: a staged update is installed without reopening.
    func installOnQuit() {
        guard case .ready = state else { return }
        try? launchSwapHelper(relaunch: false)
    }

    private func apply(relaunch: Bool) {
        do {
            try launchSwapHelper(relaunch: relaunch)
            state = .installing
            stagedApp = nil // the helper owns it now; don't install twice on quit
            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// A detached shell helper waits for this process to exit, replaces the bundle
    /// (restoring the old one if the copy fails) and optionally reopens Cadence.
    private func launchSwapHelper(relaunch: Bool) throws {
        guard let newApp = stagedApp else { throw UpdateError("No update is ready.") }
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$3.old"
        if mv "$3" "$3.old" && /usr/bin/ditto "$2" "$3"; then
          rm -rf "$3.old"
        else
          rm -rf "$3"; mv "$3.old" "$3"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$3" 2>/dev/null
        [ "$4" = 1 ] && /usr/bin/open "$3"
        exit 0
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "cadence-update",
                             String(ProcessInfo.processInfo.processIdentifier),
                             newApp.path, Bundle.main.bundleURL.path, relaunch ? "1" : "0"]
        try process.run()
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }

    private static func run(_ tool: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: UpdateError("\((tool as NSString).lastPathComponent) failed while installing the update."))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}

private struct UpdateError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let body: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case assets
    }
}
