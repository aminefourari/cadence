import AppKit
import Foundation
import SwiftUI
import WebKit

enum YouTubeURL {
    static func extractVideoID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        guard !trimmed.isEmpty else { return nil }

        if trimmed.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil {
            return trimmed
        }

        let normalized = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: normalized) else { return nil }
        let host = components.host?.lowercased() ?? ""
        guard host.contains("youtube.com") || host.contains("youtu.be") else { return nil }

        if host.contains("youtu.be") {
            let candidate = components.path.split(separator: "/").first.map(String.init)
            return candidate.flatMap(validID)
        }

        if let value = components.queryItems?.first(where: { $0.name == "v" })?.value,
           let id = validID(value) {
            return id
        }

        let parts = components.path.split(separator: "/").map(String.init)
        if let marker = parts.firstIndex(where: { ["embed", "shorts", "live", "v"].contains($0) }),
           parts.indices.contains(marker + 1) {
            return validID(parts[marker + 1])
        }
        return nil
    }

    private static func validID(_ value: String) -> String? {
        value.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil ? value : nil
    }
}

@MainActor
final class YouTubePlayerController: NSObject, ObservableObject {
    @Published private(set) var videoID: String = ""
    @Published private(set) var title: String = "Nothing playing yet"
    @Published private(set) var author: String = ""
    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var isLive = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var volume: Double = 70
    @Published private(set) var isMuted = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isImportingFromBrave = false
    @Published private(set) var braveImportMessage: String?

    private var webViewStorage: WKWebView?
    private var pollTimer: Timer?
    private var isPolling = false
    private var pendingAutoplay = false
    private var pendingSeek: Double?
    private var needsVolumeApply = true
    private var loadStartedAt = Date()
    private var hasAttemptedBraveImport = false

    var hasVideo: Bool { !videoID.isEmpty }

    override init() {
        super.init()
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--video=") }) {
            let value = String(argument.dropFirst("--video=".count))
            if let id = YouTubeURL.extractVideoID(from: value) {
                videoID = id
                isLoading = true
            }
        }
    }

    var webView: WKWebView {
        if let webViewStorage {
            return webViewStorage
        }
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let css = ".html5-video-player > :not(.html5-video-container) { display: none !important; } .ytp-ad-module, .video-ads, .ytp-ad-overlay-container { display: none !important; } html, body { background: #000 !important; }"
        let hideChrome = "const style = document.createElement('style'); style.textContent = '\(css)'; document.documentElement.appendChild(style);"
        configuration.userContentController.addUserScript(
            WKUserScript(source: hideChrome, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        webViewStorage = webView
        if hasVideo {
            loadEmbeddedPage()
        } else {
            loadBlankPage()
        }
        startPolling()
        return webView
    }

    var watchURL: URL? {
        guard hasVideo else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
    }

    func loadInput(_ input: String) -> Bool {
        guard let id = YouTubeURL.extractVideoID(from: input) else {
            errorMessage = "Paste a YouTube link or an 11-character video ID."
            return false
        }
        loadVideo(id: id, autoplay: true)
        return true
    }

    func loadVideo(
        id: String,
        autoplay: Bool,
        startAt: Double? = nil,
        volume: Double? = nil,
        title: String? = nil,
        author: String? = nil
    ) {
        guard !id.isEmpty else { return }
        videoID = id
        self.title = (title?.isEmpty == false) ? title! : "Loading YouTube…"
        self.author = author ?? ""
        isReady = false
        isLoading = true
        isPlaying = false
        isBuffering = false
        isLive = false
        currentTime = 0
        duration = 0
        errorMessage = nil
        pendingAutoplay = autoplay
        pendingSeek = startAt
        if let volume {
            self.volume = min(100, max(0, volume))
        }
        needsVolumeApply = true
        loadStartedAt = Date()
        loadEmbeddedPage()
    }

    func reload() {
        guard hasVideo else { return }
        loadVideo(id: videoID, autoplay: false)
    }

    func autoImportFromBraveIfNeeded() {
        guard !hasVideo, !hasAttemptedBraveImport, !isImportingFromBrave else { return }
        hasAttemptedBraveImport = true
        importFromBrave()
    }

    func importFromBrave() {
        guard !isImportingFromBrave else { return }
        isImportingFromBrave = true
        braveImportMessage = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            let result: Result<BraveVideoImport, Error> = Result {
                try BraveImporter.activeVideo()
            }
            guard let self else { return }
            await MainActor.run {
                self.isImportingFromBrave = false
                switch result {
                case .success(let video):
                    self.braveImportMessage = nil
                    self.loadVideo(
                        id: video.videoID,
                        autoplay: video.wasPlaying,
                        startAt: video.currentTime,
                        volume: video.volume,
                        title: video.title,
                        author: video.author
                    )
                case .failure(let error):
                    self.braveImportMessage = error.localizedDescription
                }
            }
        }
    }

    func play() {
        guard let webView = webViewStorage else {
            pendingAutoplay = true
            return
        }
        if !isReady {
            pendingAutoplay = true
        }
        webView.evaluateJavaScript("document.getElementById('movie_player')?.playVideo()")
        isPlaying = true
    }

    func pause() {
        webViewStorage?.evaluateJavaScript("document.getElementById('movie_player')?.pauseVideo()")
        isPlaying = false
        pendingAutoplay = false
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        guard duration > 0 else { return }
        let target = min(duration, max(0, seconds))
        currentTime = target
        webViewStorage?.evaluateJavaScript(
            "document.getElementById('movie_player')?.seekTo(\(target), true)"
        )
    }

    func setVolume(_ value: Double) {
        let clamped = min(100, max(0, value))
        volume = clamped
        if clamped > 0 { isMuted = false }
        webViewStorage?.evaluateJavaScript(
            "(() => { const p=document.getElementById('movie_player'); if(p){p.setVolume(\(Int(clamped))); p.unMute();} })()"
        )
    }

    func toggleMute() {
        if isMuted {
            isMuted = false
            webViewStorage?.evaluateJavaScript("document.getElementById('movie_player')?.unMute()")
        } else {
            isMuted = true
            webViewStorage?.evaluateJavaScript("document.getElementById('movie_player')?.mute()")
        }
    }

    private func loadEmbeddedPage() {
        guard let webView = webViewStorage else { return }
        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoID)")!
        components.queryItems = [
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "controls", value: "0"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "modestbranding", value: "1"),
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "autoplay", value: "0"),
            URLQueryItem(name: "origin", value: "https://cadence.app")
        ]
        var request = URLRequest(url: components.url!)
        // YouTube's embedded player requires a valid HTTP referrer.
        request.setValue("https://cadence.app/", forHTTPHeaderField: "Referer")
        webView.load(request)
    }

    private func loadBlankPage() {
        guard let webView = webViewStorage else { return }
        let html = """
        <!doctype html>
        <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style>
        </head><body></body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://cadence.app/"))
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func refreshStatus() {
        guard let webView = webViewStorage, !isPolling else { return }
        isPolling = true
        let javascript = """
        (() => {
          const p = document.getElementById('movie_player');
          if (!p) return JSON.stringify({ready: false});
          let data = {};
          try { data = p.getVideoData ? (p.getVideoData() || {}) : {}; } catch (error) {}
          let fatalError = '';
          try {
            const errorEl = document.querySelector('.ytp-error-content-wrap-reason, .ytp-error-content, .ytp-error');
            if (errorEl) fatalError = (errorEl.textContent || '').trim();
          } catch (error) {}
          return JSON.stringify({
            ready: true,
            state: p.getPlayerState ? p.getPlayerState() : -1,
            currentTime: p.getCurrentTime ? p.getCurrentTime() : 0,
            duration: p.getDuration ? p.getDuration() : 0,
            volume: p.getVolume ? p.getVolume() : 0,
            muted: p.isMuted ? p.isMuted() : false,
            title: data.title || '',
            author: data.author || '',
            videoId: data.video_id || '',
            isLive: !!(data.isLive || data.isLiveNow || (p.getDuration && p.getDuration() > 86400)),
            fatalError: fatalError
          });
        })()
        """
        webView.evaluateJavaScript(javascript) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                self.isPolling = false
                if let error {
                    if Date().timeIntervalSince(self.loadStartedAt) > 12 {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    return
                }
                guard let text = result as? String,
                      let data = text.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      (object["ready"] as? Bool) == true else { return }
                self.applyStatus(object)
            }
        }
    }

    private func applyStatus(_ object: [String: Any]) {
        isLoading = false
        let fatal = (object["fatalError"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fatal.isEmpty {
            isReady = false
            isPlaying = false
            isBuffering = false
            errorMessage = fatal
            if title == "Loading YouTube…" { title = "Video unavailable" }
            return
        }

        isReady = true
        if let title = object["title"] as? String, !title.isEmpty {
            self.title = title
        }
        if let author = object["author"] as? String, !author.isEmpty {
            self.author = author
        }
        if let videoID = object["videoId"] as? String, !videoID.isEmpty {
            self.videoID = videoID
        }
        let state = object["state"] as? Int ?? -1
        isPlaying = state == 1
        isBuffering = state == 3
        if let live = object["isLive"] as? Bool {
            isLive = live
        }
        currentTime = (object["currentTime"] as? NSNumber)?.doubleValue ?? currentTime
        duration = (object["duration"] as? NSNumber)?.doubleValue ?? duration
        if let number = object["volume"] as? NSNumber {
            volume = number.doubleValue
        }
        if let muted = object["muted"] as? Bool {
            isMuted = muted
        }

        if needsVolumeApply {
            needsVolumeApply = false
            webViewStorage?.evaluateJavaScript(
                "(() => { const p=document.getElementById('movie_player'); if(p){p.setVolume(\(Int(volume))); p.unMute();} })()"
            )
        }
        if let pendingSeek, pendingSeek > 0 {
            self.pendingSeek = nil
            webViewStorage?.evaluateJavaScript(
                "document.getElementById('movie_player')?.seekTo(\(pendingSeek), true)"
            )
        }
        if pendingAutoplay && !isPlaying {
            pendingAutoplay = false
            play()
        }
        if state == 1 {
            errorMessage = nil
        }
    }
}

extension YouTubePlayerController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
           navigationAction.navigationType == .linkActivated,
           !url.absoluteString.contains("/embed/") {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadStartedAt = Date()
        refreshStatus()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        errorMessage = error.localizedDescription
        isLoading = false
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}

struct YouTubePlayerWebView: NSViewRepresentable {
    @ObservedObject var player: YouTubePlayerController

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        let webView = player.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
