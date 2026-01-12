////
////  ChessSpeechInterpreter.swift
////  Blind Chess
////
////  Created by Tyler Hartman on 1/10/26.
////
//
//import Foundation
//
//class ChessSpeechInterpreter: ObservableObject {
//    static let shared = ChessSpeechInterpreter()
//    
//    // The "Memory" of what we were just talking about
//    enum InterpretationState {
//        case idle
//        case awaitingClarification(targetSquare: String, pieceChar: String)
//    }
//    
//    private var state: InterpretationState = .idle
//    
//    // MARK: - Entry Point
//    func parseRawText(_ text: String) {
//        let normalized = normalize(text)
//        print("🧠 Interpreter: Analyzing [\(normalized)]")
//        
//        switch state {
//        case .idle:
//            handleStandardMove(normalized)
//        case .awaitingClarification(let target, let piece):
//            handleClarification(normalized, target: target, piece: piece)
//        }
//    }
//    
//    // MARK: - Internal Logic
//    private func normalize(_ text: String) -> String {
//        let replacements = ["night": "knight", "nite": "knight", "ponde": "pawn", "to": " ", "see": "c", "if": "f"]
//        var t = text.lowercased()
//        for (k, v) in replacements { t = t.replacingOccurrences(of: k, with: v) }
//        return t
//    }
//    
//    private func handleStandardMove(_ text: String) {
//        let pieces = ["pawn", "knight", "bishop", "rook", "queen", "king"]
//        guard let piece = pieces.last(where: { text.contains($0) }) else { return }
//        
//        let files = "abcdefgh", ranks = "12345678"
//        var square = ""
//        for f in files {
//            for r in ranks {
//                if text.contains("\(f)\(r)") { square = "\(f)\(r)" }
//            }
//        }
//        
//        // Inside ChessSpeechInterpreter handleStandardMove
//        if !square.isEmpty {
//            ChessGameManager.shared.attemptMove(
//                piece: piece,
//                to: square,
//                isWhite: true, // Or your variable for turn
//                webView: webView, // Pass your webView reference
//                coordinator: coordinator
//            )
//        }
//    }
//    
//    private func handleClarification(_ text: String, target: String, piece: String) {
//        let fileMap = ["a":"1", "b":"2", "c":"3", "d":"4", "e":"5", "f":"6", "g":"7", "h":"8"]
//        let rankList = ["1", "2", "3", "4", "5", "6", "7", "8"]
//        
//        var modifier: String?
//        for (fName, fVal) in fileMap where text.contains(fName) { modifier = fVal }
//        if modifier == nil {
//            for r in rankList where text.contains(r) { modifier = r }
//        }
//        
//        if let mod = modifier {
//            state = .idle // Reset state
//            ChessGameManager.shared.executeFilteredMove(piece: piece, target: target, modifier: mod)
//        }
//    }
//    
//    // Called by GameManager when it finds 2+ pieces
//    func setClarificationContext(target: String, piece: String) {
//        self.state = .awaitingClarification(targetSquare: target, pieceChar: piece)
//    }
//}
