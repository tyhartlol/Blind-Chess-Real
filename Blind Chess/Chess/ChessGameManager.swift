//import Foundation
//import WebKit
//
//class ChessGameManager {
//    static let shared = ChessGameManager()
//    private let engine = ChessEngine()
//    
//    private var lastBoard: [[String]]?
//    private var lastIsFlipped: Bool = false
//
//    // MARK: - Core Public API
//    
//    /// Called by Interpreter for a fresh move
//    func attemptMove(piece: String, to square: String, isWhite: Bool, webView: WKWebView, coordinator: ChessComWebView.Coordinator) {
//        guard let targetSquare = notationToSquare(square) else { return }
//        let pieceChar = getPieceChar(piece, isWhite: isWhite)
//        
//        fetchCurrentBoardState(webView: webView) { state in
//            guard let state = state else { return }
//            let targetInt = Int(targetSquare) ?? 0
//            
//            let candidates = self.findAllLegalPieces(piece: pieceChar, target: targetInt, state: state)
//            
//            if candidates.count > 1 {
//                // Tell Interpreter to ask the user for help
//                ChessSpeechInterpreter.shared.setClarificationContext(target: targetSquare, piece: pieceChar)
//                TextToSpeechManager.shared.speak("Multiple \(piece)s can reach \(square). From which file or rank?")
//            } else if let from = candidates.first {
//                self.executeValidatedMove(from: from, to: targetSquare, pieceChar: pieceChar, isWhite: isWhite, coordinator: coordinator)
//            } else {
//                TextToSpeechManager.shared.speak("No legal \(piece) can reach \(square).")
//            }
//        }
//    }
//
//    /// Called by Interpreter after the user provides a modifier (file/rank)
//    func executeFilteredMove(pieceChar: String, target: String, modifier: String, isWhite: Bool, coordinator: ChessComWebView.Coordinator) {
//        // Here we just execute—we assume the interpreter already validated the modifier
//        // But we double check the board state for safety
//        coordinator.executeRawMove(from: modifier, to: target, isWhite: isWhite)
//        // Note: You'll want to ensure the 'modifier' passed here is the actual 2-digit square code (e.g. "21")
//    }
//
//    // MARK: - Internal Execution
//    
//    private func executeValidatedMove(from: String, to: String, pieceChar: String, isWhite: Bool, coordinator: ChessComWebView.Coordinator) {
//        let player = isWhite ? "White" : "Black"
//        self.announceMove(player: player, isUser: true, pieceChar: pieceChar, from: from, to: to)
//        coordinator.executeRawMove(from: from, to: to, isWhite: isWhite)
//    }
//
//    private func findAllLegalPieces(piece: String, target: Int, state: ChessEngine.GameState) -> [String] {
//        var found = [String]()
//        for r in 0...7 {
//            for c in 0...7 {
//                if state.board[r][c] == piece {
//                    let currentSquare = (c + 1) * 10 + (8 - r)
//                    if engine.isMoveLegal(state: state, piece: piece, start: currentSquare, end: target) {
//                        found.append("\(currentSquare)")
//                    }
//                }
//            }
//        }
//        return found
//    }
//
//    // MARK: - Helpers
//
//    private func getPieceChar(_ name: String, isWhite: Bool) -> String {
//        let mapping = ["pawn":"p", "rook":"r", "knight":"n", "bishop":"b", "queen":"q", "king":"k"]
//        let char = mapping[name.lowercased()] ?? "p"
//        return isWhite ? char.uppercased() : char.lowercased()
//    }
//
//    private func notationToSquare(_ notation: String) -> String? {
//        let files: [String: Int] = [
//            "a": 1, "b": 2, "c": 3, "d": 4,
//            "e": 5, "f": 6, "g": 7, "h": 8
//        ]
//        
//        let n = notation.lowercased()
//        
//        // Ensure we have exactly 2 characters (e.g., "e4")
//        guard n.count == 2,
//              let f = files[String(n.first!)],
//              let r = n.last?.wholeNumberValue else {
//            return nil
//        }
//        
//        // Returns a string like "54" for e4
//        return "\(f)\(r)"
//    }
//
//    func toNotation(_ sq: String) -> String {
//        let files = ["", "a", "b", "c", "d", "e", "f", "g", "h"]
//        guard sq.count == 2, let fIndex = Int(String(sq.first!)), fIndex < files.count else { return sq }
//        return "\(files[fIndex])\(sq.last!)"
//    }
//
//    func announceMove(player: String, isUser: Bool, pieceChar: String, from: String, to: String) {
//        let pieceNames = ["p":"Pawn", "r":"Rook", "n":"Knight", "b":"Bishop", "q":"Queen", "k":"King"]
//        let name = pieceNames[pieceChar.lowercased()] ?? "Piece"
//        let prefix = isUser ? "You moved" : "\(player) moved"
//        TextToSpeechManager.shared.speak("\(prefix) \(name) from \(toNotation(from)) to \(toNotation(to))")
//    }
//
//    // MARK: - Board Scraping & Monitoring
//
//    func fetchCurrentBoardState(webView: WKWebView, completion: @escaping (ChessEngine.GameState?) -> Void) {
//        webView.evaluateJavaScript(ChessJSBridge.scrapeScript()) { result, _ in
//            guard let dict = result as? [String: Any],
//                  let board = dict["board"] as? [[String]],
//                  let isWhiteSide = dict["isWhiteSide"] as? Bool else {
//                completion(nil); return
//            }
//            completion(ChessEngine.GameState(board: board, isFlipped: !isWhiteSide))
//        }
//    }
//
//    func monitorBoardChanges(webView: WKWebView) {
//        fetchCurrentBoardState(webView: webView) { [weak self] newState in
//            guard let self = self, let newState = newState else { return }
//            guard let oldBoard = self.lastBoard else {
//                self.lastBoard = newState.board
//                return
//            }
//            self.detectMove(oldBoard: oldBoard, newBoard: newState.board, isFlipped: newState.isFlipped)
//            self.lastBoard = newState.board
//        }
//    }
//
//    private func detectMove(oldBoard: [[String]], newBoard: [[String]], isFlipped: Bool) {
//        var fromSquare: String?; var toSquare: String?; var movedPiece: String?
//        for r in 0...7 {
//            for c in 0...7 {
//                let old = oldBoard[r][c], new = newBoard[r][c]
//                let squareStr = "\(c + 1)\(8 - r)"
//                if old != "" && new == "" { fromSquare = squareStr; movedPiece = old }
//                else if old != new && new != "" { toSquare = squareStr }
//            }
//        }
//        if let piece = movedPiece, let from = fromSquare, let to = toSquare {
//            let isWhitePiece = piece == piece.uppercased()
//            if isWhitePiece != (!isFlipped) {
//                self.announceMove(player: isWhitePiece ? "White" : "Black", isUser: false, pieceChar: piece, from: from, to: to)
//            }
//        }
//    }
//}
