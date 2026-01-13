import Foundation
import WebKit

class ChessGameManager {
    static let shared = ChessGameManager()
    private let engine = ChessEngine()
    
    // Tracks who moved last: "white" or "black"
    private var lastMovedColor: String = "black"

    func start(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech, isWhite: Bool) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            
            let myColor = isWhite ? "white" : "black"
            let p = speech.firstPiece
            let s = speech.firstSquare
            
            // 1. Check the Turn Gate
            if self.lastMovedColor == myColor {
                // If the last move was mine, I must wait for the opponent
                print("Opponent's Turn")
            }
            else {
                print("User's Turn")
            }

            // 2. If it is my turn, check for speech
            if p != "None" && s != "None" {
                print("🕹️ Turn Active: Processing User Move [\(p) to \(s)]")
                
                webView.evaluateJavaScript(ChessJSBridge.scrapeScript()) { result, _ in
                    guard let dict = result as? [String: Any],
                          let board = dict["board"] as? [[String]],
                          let isWhiteSide = dict["isWhiteSide"] as? Bool else { return }
                    
                    let state = ChessEngine.GameState(board: board, isFlipped: !isWhiteSide)
                    guard let targetSquare = self.notationToSquare(s) else { return }
                    
                    let pieceChar = self.getPieceChar(p, isWhite: isWhite)
                    let candidates = self.findAllLegalPieces(piece: pieceChar, target: Int(targetSquare) ?? 0, state: state)
                    
                    if candidates.count == 1 {
                        coordinator.executeMoveScript(from: candidates.first!, to: targetSquare, isWhite: isWhite)
                        DispatchQueue.main.async { speech.reset() }
                    } else {
                        print("⚠️ Cannot move: \(candidates.count) pieces found.")
                        DispatchQueue.main.async { speech.reset() }
                    }
                }
            }
        }
    }

    func updateTurn(piece: String, from: String, to: String, isWhitePlayer: Bool) {
        let pieceColor = (piece == piece.uppercased()) ? "white" : "black"
        let myColor = isWhitePlayer ? "white" : "black"
        
        // 1. Identify if it's the User or the Opponent
        let isUserMove = (pieceColor == myColor)
        
        // 2. Format the piece name for speech (e.g., 'P' -> 'Pawn')
        let fullPieceName = expandPieceName(piece)
        
        // 3. Construct the sentence
        let sentence: String
        if isUserMove {
            sentence = "You moved \(fullPieceName) from \(from) to \(to)"
        } else {
            // Uppercase the first letter of the color for the Opponent string
            let opponentColor = pieceColor.capitalized
            sentence = "\(opponentColor) moved \(fullPieceName) from \(from) to \(to)"
        }

        // 4. Update Turn State and Print to Console
        if pieceColor != self.lastMovedColor {
            self.lastMovedColor = pieceColor
            print("📢 QUEUING SPEECH: \(sentence)")
            
            // 5. TEST: Call the queue function
            TextToSpeechManager.shared.queueSpeak(sentence)
            
            if self.lastMovedColor == myColor {
                print("⏳ WAITING ON: Opponent")
            } else {
                print("🟢 WAITING ON: User (Your Turn)")
            }
        }
    }

    // Helper to make the speech sound natural
    private func expandPieceName(_ char: String) -> String {
        let names = [
            "p": "Pawn", "r": "Rook", "n": "Knight",
            "b": "Bishop", "q": "Queen", "k": "King"
        ]
        return names[char.lowercased()] ?? "Piece"
    }

    private func getPieceChar(_ name: String, isWhite: Bool) -> String {
        let mapping = ["pawn":"p", "rook":"r", "knight":"n", "night":"n", "bishop":"b", "queen":"q", "king":"k"]
        let char = mapping[name.lowercased()] ?? "p"
        return isWhite ? char.uppercased() : char.lowercased()
    }

    private func notationToSquare(_ notation: String) -> String? {
        let clean = notation.lowercased().trimmingCharacters(in: .whitespaces)
        let files: [String: Int] = ["a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8]
        guard clean.count == 2, let f = files[String(clean.prefix(1))] else { return nil }
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
