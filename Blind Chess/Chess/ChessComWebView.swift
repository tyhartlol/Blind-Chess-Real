import SwiftUI
import WebKit

struct ChessComWebView: UIViewRepresentable {
    let url: URL
    @Binding var moveCommand: ChessMove?
    @Binding var isPlayingWhite: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let move = moveCommand {
            ChessGameManager.shared.processMove(move, webView: uiView, coordinator: context.coordinator) { newSide in
                DispatchQueue.main.async {
                    self.isPlayingWhite = newSide
                    // This triggers the reset in the ViewModel
                    NotificationCenter.default.post(name: NSNotification.Name("ClearMoveUI"), object: nil)
                }
            }
            DispatchQueue.main.async { moveCommand = nil }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ChessComWebView
        weak var webView: WKWebView?
        var detectionTimer: Timer?
        
        init(parent: ChessComWebView) { self.parent = parent }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(ChessJSBridge.injectionScript())
            startMonitoring()
        }

        func startMonitoring() {
            detectionTimer?.invalidate()
            detectionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                guard let web = self.webView else { return }
                ChessGameManager.shared.monitorBoardChanges(webView: web)
            }
        }

        func executeRawMove(from: String, to: String, isWhite: Bool) {
            let moveJS = ChessJSBridge.moveScript(from: from, to: to, isWhite: isWhite)
            webView?.evaluateJavaScript(moveJS) { _, error in
                if let error = error { print("⚠️ JS ERROR: \(error.localizedDescription)") }
            }
        }
    }
}
