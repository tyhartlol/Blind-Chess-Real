import Foundation
import WebKit

class ChessGameManager {
    static let shared = ChessGameManager()
    private let engine = ChessEngine()
    private var lastMovedPieceColor: String = "black"

    func start(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech, isWhite: Bool) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            
            let myColor = isWhite ? "white" : "black"
            let p = speech.firstPiece
            let s = speech.firstSquare
            
            if p != "None" && s != "None" {
                print("📝 MANAGER: Detected [\(p) to \(s)]")
                
                if self.lastMovedPieceColor == myColor {
                    print("🚥 MANAGER: Waiting for opponent move...")
                    return
                }

                webView.evaluateJavaScript(ChessJSBridge.scrapeScript()) { result, _ in
                    guard let dict = result as? [String: Any],
                          let board = dict["board"] as? [[String]],
                          let isWhiteSide = dict["isWhiteSide"] as? Bool else { return }
                    
                    let state = ChessEngine.GameState(board: board, isFlipped: !isWhiteSide)
                    guard let targetSquare = self.notationToSquare(s) else { return }
                    
                    let pieceChar = self.getPieceChar(p, isWhite: isWhite)
                    let candidates = self.findAllLegalPieces(piece: pieceChar, target: Int(targetSquare) ?? 0, state: state)
                    
                    if candidates.count == 1 {
                        print("🚀 MANAGER: Valid move found. Sending script...")
                        // Use your moveScript directly here
                        coordinator.executeMoveScript(from: candidates.first!, to: targetSquare, isWhite: isWhite)
                        
                        DispatchQueue.main.async { speech.reset() }
                    } else {
                        print("❌ MANAGER: Move illegal or ambiguous (\(candidates.count) found)")
                        DispatchQueue.main.async { speech.reset() }
                    }
                }
            }
        }
    }

    func updateLastMove(piece: String, from: String, to: String) {
        self.lastMovedPieceColor = (piece == piece.uppercased()) ? "white" : "black"
    }

    private func getPieceChar(_ name: String, isWhite: Bool) -> String {
        let mapping = ["pawn":"p", "rook":"r", "knight":"n", "night":"n", "bishop":"b", "queen":"q", "king":"k"]
        let char = mapping[name.lowercased()] ?? "p"
        return isWhite ? char.uppercased() : char.lowercased()
    }

    private func notationToSquare(_ notation: String) -> String? {
        let clean = notation.lowercased().trimmingCharacters(in: .whitespaces)
        let files: [String: Int] = ["a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8]
        guard clean.count == 2,
              let f = files[String(clean.prefix(1))],
              let _ = Int(String(clean.suffix(1))) else { return nil }
        return "\(f)\(clean.suffix(1))"
    }

    func indicesToNotation(row: Int, col: Int) -> String {
        let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
        return "\(files[col])\(8 - row)"
    }

    private func findAllLegalPieces(piece: String, target: Int, state: ChessEngine.GameState) -> [String] {
        var found = [String]()
        for r in 0...7 {
            for c in 0...7 where state.board[r][c] == piece {
                let sq = (c + 1) * 10 + (8 - r)
                if engine.isMoveLegal(state: state, piece: piece, start: sq, end: target) {
                    found.append("\(sq)")
                }
            }
        }
        return found
    }
}
