import AppKit
import Foundation

struct BraveVideoImport {
    let videoID: String
    let url: String
    let title: String
    let author: String
    let currentTime: Double
    let duration: Double
    let volume: Double
    let wasPlaying: Bool
}

enum BraveImportError: LocalizedError {
    case braveNotRunning
    case noYouTubeTab
    case automationDenied
    case javascriptDisabled
    case timedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .braveNotRunning:
            return "Brave isn't running. Open a YouTube video in Brave, then try again."
        case .noYouTubeTab:
            return "No YouTube video tab was found in Brave."
        case .automationDenied:
            return "macOS blocked Cadence from reading Brave. Allow Cadence in System Settings → Privacy & Security → Automation."
        case .javascriptDisabled:
            return "Enable View → Developer → Allow JavaScript from Apple Events in Brave, then try again."
        case .timedOut:
            return "Brave did not answer. Finish any macOS permission prompt, then try again."
        case .failed(let message):
            return message
        }
    }
}

enum BraveImporter {
    private static let bridgeScript = #"""
    on run argv
      set jsSource to item 1 of argv
      tell application "Brave Browser"
        set targetTab to missing value
        try
          set activeTab to active tab of front window
          if (URL of activeTab) contains "youtube.com" then
            set targetTab to activeTab
          end if
        end try
        if targetTab is missing value then
          repeat with w in windows
            repeat with t in tabs of w
              if (URL of t) contains "youtube.com" then
                set targetTab to t
                exit repeat
              end if
            end repeat
            if targetTab is not missing value then exit repeat
          end repeat
        end if
        if targetTab is missing value then return "NO_TAB"
        try
          set jsResult to execute targetTab javascript jsSource
          return jsResult as text
        on error errMsg number errNum
          return "ERR|||" & (errMsg as text)
        end try
      end tell
    end run
    """#

    private static let importJavaScript = #"""
    (() => {
      try {
        const v = document.querySelector('video');
        if (!v) return JSON.stringify({ok:false, code:'no_video', message:'No YouTube video is loaded.'});
        const player = document.querySelector('#movie_player');
        let title = '';
        let author = '';
        let videoId = '';
        try {
          const data = player && player.getVideoData ? (player.getVideoData() || {}) : {};
          title = data.title || '';
          author = data.author || '';
          videoId = data.video_id || '';
        } catch (error) {}
        if (!title) {
          const heading = document.querySelector('h1 yt-formatted-string, h1.title');
          title = heading ? heading.textContent.trim() : document.title.replace(/ - YouTube$/, '');
        }
        if (!videoId) {
          const match = location.href.match(/[?&]v=([^&]+)/);
          videoId = match ? match[1] : '';
        }
        const wasPlaying = !v.paused;
        const currentTime = Number.isFinite(v.currentTime) ? v.currentTime : 0;
        const duration = Number.isFinite(v.duration) ? v.duration : 0;
        const volume = Math.round((v.volume || 0) * 100);
        if (wasPlaying) { v.pause(); }
        return JSON.stringify({
          ok: true,
          url: location.href,
          title: title,
          author: author,
          videoId: videoId,
          currentTime: currentTime,
          duration: duration,
          volume: volume,
          wasPlaying: wasPlaying
        });
      } catch (error) {
        return JSON.stringify({ok:false, code:'javascript_error', message:String(error)});
      }
    })()
    """#

    static func activeVideo() throws -> BraveVideoImport {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.brave.Browser").isEmpty else {
            throw BraveImportError.braveNotRunning
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", bridgeScript, "--", importJavaScript]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw BraveImportError.failed("Could not launch AppleScript: \(error.localizedDescription)")
        }

        let deadline = Date().addingTimeInterval(25)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            throw BraveImportError.timedOut
        }

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if stdout == "NO_TAB" {
            throw BraveImportError.noYouTubeTab
        }
        if stdout.hasPrefix("ERR|||") {
            let message = String(stdout.dropFirst(6))
            throw classify(message)
        }
        if !stderr.isEmpty {
            throw classify(stderr)
        }
        guard !stdout.isEmpty else {
            throw BraveImportError.failed("Brave returned an empty response.")
        }

        guard let data = stdout.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BraveImportError.failed("Brave returned an unreadable video state.")
        }
        if object["ok"] as? Bool != true {
            throw classify(object["message"] as? String ?? "YouTube could not be read.")
        }

        let url = object["url"] as? String ?? ""
        let videoID = (object["videoId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? YouTubeURL.extractVideoID(from: url)
        guard let videoID else {
            throw BraveImportError.failed("Could not find a video ID in the Brave tab.")
        }

        return BraveVideoImport(
            videoID: videoID,
            url: url,
            title: object["title"] as? String ?? "YouTube",
            author: object["author"] as? String ?? "",
            currentTime: object["currentTime"] as? Double ?? 0,
            duration: object["duration"] as? Double ?? 0,
            volume: object["volume"] as? Double ?? 70,
            wasPlaying: object["wasPlaying"] as? Bool ?? false
        )
    }

    private static func classify(_ message: String) -> BraveImportError {
        let lower = message.lowercased()
        if lower.contains("not authorized")
            || lower.contains("-1743")
            || lower.contains("-10004")
            || lower.contains("privilege violation")
            || lower.contains("not permitted") {
            return .automationDenied
        }
        if lower.contains("javascript")
            || lower.contains("turned off")
            || lower.contains("-1728") {
            return .javascriptDisabled
        }
        return .failed(message)
    }
}
