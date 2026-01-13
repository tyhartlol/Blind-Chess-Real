import SwiftUI
import WebKit

struct ChessComWebView: UIViewRepresentable {
    let url: URL
    @Binding var isPlayingWhite: Bool
    @ObservedObject var normalizer: NormalizeSpeech

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Inject your CSS cleanup script on load
        let script = WKUserScript(source: ChessJSBridge.injectionScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
        
        webView.load(URLRequest(url: url))
        ChessGameManager.shared.start(webView: webView, coordinator: context.coordinator, speech: normalizer, isWhite: isPlayingWhite)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ChessComWebView
        var previousBoard: [[String]]?
        var webView: WKWebView?

        init(_ parent: ChessComWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                webView.evaluateJavaScript(ChessJSBridge.scrapeScript()) { result, _ in
                    guard let dict = result as? [String: Any], let board = dict["board"] as? [[String]] else { return }
                    if let old = self.previousBoard, old != board {
                        self.detectMove(old: old, new: board)
                    }
                    self.previousBoard = board
                }
            }
        }

        func detectMove(old: [[String]], new: [[String]]) {
            var fromStr = "", toStr = "", movedPiece = ""

            for r in 0...7 {
                for c in 0...7 {
                    let oldP = old[r][c], newP = new[r][c]
                    if !oldP.isEmpty && newP.isEmpty {
                        fromStr = ChessGameManager.shared.indicesToNotation(row: r, col: c)
                        movedPiece = oldP
                    } else if !newP.isEmpty && oldP != newP {
                        toStr = ChessGameManager.shared.indicesToNotation(row: r, col: c)
                    }
                }
            }

            if !movedPiece.isEmpty && !fromStr.isEmpty && !toStr.isEmpty {
                // Updated call to pass all move details
                ChessGameManager.shared.updateTurn(
                    piece: movedPiece,
                    from: fromStr,
                    to: toStr,
                    isWhitePlayer: parent.isPlayingWhite
                )
            }
        }

        func executeMoveScript(from: String, to: String, isWhite: Bool) {
            // This pulls the string from your working function
            let script = ChessJSBridge.moveScript(from: from, to: to, isWhite: isWhite)
            webView?.evaluateJavaScript(script) { result, error in
                if let error = error { print("❌ JS Error: \(error)") }
                if let result = result { print("✅ JS Result: \(result)") }
            }
        }
    }
}
