import AppKit
import Foundation

/// In-app updates from GitHub Releases.
///
/// Checks `releases/latest` of the repository named by `CadenceUpdateRepository` in
/// Info.plist, downloads the release's `.zip` asset, verifies it is a valid Cadence
/// bundle newer than this one, then swaps it in place of the running app and relaunches.
/// ponytail: trusts GitHub over HTTPS + bundle id + codesign integrity; add an EdDSA
/// signature check (or Developer ID + notarization) if the release channel needs hardening.
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
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    var hasUpdate: Bool {
        if case .available = state { return true }
        return false
    }

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private let repository = Bundle.main.object(forInfoDictionaryKey: "CadenceUpdateRepository") as? String
        ?? "aminefourari/cadence"
    private static let lastCheckKey = "cadence.lastUpdateCheck"

    var releasesPage: URL { URL(string: "https://github.com/\(repository)/releases")! }

    /// Checks at most once a day, silently unless an update is found.
    func checkAutomaticallyIfDue(onAvailable: @escaping (Release) -> Void) {
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
        Task {
            await check()
            if case .available(let release) = state { onAvailable(release) }
        }
    }

    func check() async {
        guard state != .checking, state != .installing else { return }
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
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)

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

    /// Downloads, verifies and installs the release, then quits so the helper can swap and relaunch.
    func install(_ release: Release) async {
        state = .installing
        do {
            let target = Bundle.main.bundleURL
            let parent = target.deletingLastPathComponent()
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
            try await Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])

            try launchSwapHelper(newApp: newApp, target: target)
            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// A detached shell helper waits for this process to exit, replaces the bundle
    /// (restoring the old one if the copy fails) and reopens Cadence.
    private func launchSwapHelper(newApp: URL, target: URL) throws {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$3.old"
        if mv "$3" "$3.old" && /usr/bin/ditto "$2" "$3"; then
          rm -rf "$3.old"
        else
          rm -rf "$3"; mv "$3.old" "$3"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$3" 2>/dev/null
        /usr/bin/open "$3"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "cadence-update",
                             String(ProcessInfo.processInfo.processIdentifier), newApp.path, target.path]
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
