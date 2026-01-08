import Foundation
import WebKit

class ChessGameManager {
    static let shared = ChessGameManager()
    private let engine = ChessEngine()
    private var lastBoard: [[String]]?
    private var lastIsFlipped: Bool = false

    // 🚀 Coordinate Conversion & Move Creation
    func createMoveCommand(piece: String, square: String, isWhite: Bool) -> ChessMove? {
        let pieceMapping: [String: String] = [
            "pawn": isWhite ? "P" : "p",
            "rook": isWhite ? "R" : "r",
            "knight": isWhite ? "N" : "n",
            "bishop": isWhite ? "B" : "b",
            "queen": isWhite ? "Q" : "q",
            "king": isWhite ? "K" : "k"
        ]

        guard let pieceChar = pieceMapping[piece.lowercased()],
              let targetSquare = notationToSquare(square) else {
            return nil
        }

        return ChessMove(from: "FIND:\(pieceChar)", to: targetSquare)
    }

    private func notationToSquare(_ notation: String) -> String? {
        let files = ["a":1, "b":2, "c":3, "d":4, "e":5, "f":6, "g":7, "h":8]
        let n = notation.lowercased()
        guard n.count == 2,
              let f = files[String(n.first!)],
              let r = n.last?.wholeNumberValue else { return nil }
        return "\(f)\(r)"
    }

    // 🚀 Move Processing
    func processMove(_ move: ChessMove, webView: WKWebView, coordinator: ChessComWebView.Coordinator, updateSide: @escaping (Bool) -> Void) {
        fetchCurrentBoardState(webView: webView) { state in
            guard let state = state else { return }
            let currentSideIsWhite = !state.isFlipped
            updateSide(currentSideIsWhite)
            
            var finalFrom: String? = nil
            let targetInt = Int(move.to) ?? 0

            if move.from.contains("FIND:") {
                let pieceName = move.from.replacingOccurrences(of: "FIND:", with: "")
                finalFrom = self.findLegalPiece(piece: pieceName, target: targetInt, state: state)
            } else {
                finalFrom = move.from
            }

            if let from = finalFrom {
                let player = currentSideIsWhite ? "White" : "Black"
                self.announceMove(player: player, isUser: true, pieceCode: move.from, fromSquare: from, targetSquare: move.to)
                coordinator.executeRawMove(from: from, to: move.to, isWhite: currentSideIsWhite)
            } else {
                TextToSpeechManager.shared.speak("No legal \(move.from) can reach \(move.to)")
                NotificationCenter.default.post(name: NSNotification.Name("ClearMoveUI"), object: nil)
            }
        }
    }

    private func findLegalPiece(piece: String, target: Int, state: ChessEngine.GameState) -> String? {
        for r in 0...7 {
            for c in 0...7 {
                if state.board[r][c] == piece {
                    let currentSquare = (c + 1) * 10 + (8 - r)
                    if engine.isMoveLegal(state: state, piece: piece, start: currentSquare, end: target) {
                        return "\(currentSquare)"
                    }
                }
            }
        }
        return nil
    }

    func announceMove(player: String, isUser: Bool, pieceCode: String, fromSquare: String, targetSquare: String) {
        let code = pieceCode.replacingOccurrences(of: "FIND:", with: "").lowercased()
        let pieceNames = ["p":"Pawn", "r":"Rook", "n":"Knight", "b":"Bishop", "q":"Queen", "k":"King"]
        let pieceName = pieceNames[code] ?? "Piece"
        
        let files = ["", "a", "b", "c", "d", "e", "f", "g", "h"]
        let toNotation = { (sq: String) -> String in
            guard sq.count == 2 else { return sq }
            let f = Int(String(sq.first!)) ?? 0
            return "\(files[f])\(sq.last!)"
        }
        
        let prefix = isUser ? "You moved" : "\(player) moved"
        TextToSpeechManager.shared.speak("\(prefix) \(pieceName) from \(toNotation(fromSquare)) to \(toNotation(targetSquare))")
    }

    private func fetchCurrentBoardState(webView: WKWebView, completion: @escaping (ChessEngine.GameState?) -> Void) {
        webView.evaluateJavaScript(ChessJSBridge.scrapeScript()) { result, _ in
            guard let dict = result as? [String: Any],
                  let board = dict["board"] as? [[String]],
                  let isWhiteSide = dict["isWhiteSide"] as? Bool else {
                completion(nil); return
            }
            completion(ChessEngine.GameState(board: board, isFlipped: !isWhiteSide))
        }
    }

    func monitorBoardChanges(webView: WKWebView) {
        fetchCurrentBoardState(webView: webView) { [weak self] newState in
            guard let self = self, let newState = newState else { return }
            guard let oldBoard = self.lastBoard else {
                self.lastBoard = newState.board
                self.lastIsFlipped = newState.isFlipped
                return
            }
            self.detectMove(oldBoard: oldBoard, newBoard: newState.board, isFlipped: newState.isFlipped)
            self.lastBoard = newState.board
            self.lastIsFlipped = newState.isFlipped
        }
    }

    private func detectMove(oldBoard: [[String]], newBoard: [[String]], isFlipped: Bool) {
        var fromSquare: String?; var toSquare: String?; var movedPiece: String?

        for r in 0...7 {
            for c in 0...7 {
                let old = oldBoard[r][c]; let new = newBoard[r][c]
                let squareStr = "\(c + 1)\(8 - r)"
                if old != "" && new == "" { fromSquare = squareStr; movedPiece = old }
                else if old != new && new != "" { toSquare = squareStr }
            }
        }

        if let piece = movedPiece, let from = fromSquare, let to = toSquare {
            let isWhitePiece = piece == piece.uppercased()
            let userIsWhite = !isFlipped
            if isWhitePiece != userIsWhite {
                self.announceMove(player: isWhitePiece ? "White" : "Black", isUser: false, pieceCode: piece, fromSquare: from, targetSquare: to)
            }
        }
    }
}
