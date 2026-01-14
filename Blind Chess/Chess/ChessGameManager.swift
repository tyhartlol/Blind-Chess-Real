import Foundation
import WebKit
import SwiftUI

/// Represents the current state of the game loop
enum GameStage {
    case usersTurn             // Stage 1: Waiting for piece/square voice input
    case processingUserMove    // Stage 2: Validating and executing the move
    case awaitingClarification // Stage 4: More than one piece can move to the target
    case opponentsTurn         // Stage 3: Waiting for the opponent to finish moving
}

class ChessGameManager {
    static let shared = ChessGameManager()
    private let engine = ChessEngine()
    
    // Internal State Tracking
    private var stage: GameStage = .usersTurn
    private var lastMovedColor: String = "black"
    
    // Stored data for when a move is ambiguous
    private var ambiguousCandidates: [String] = []
    private var pendingTargetSquare: String = ""
    
    var pieceName : String = ""

    /// Starts the game loop heartbeat
    func start(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech, isWhite: Bool) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.runEngine(webView: webView, coordinator: coordinator, speech: speech, isWhite: isWhite)
        }
    }

    // MARK: - Main Switchboard (The Brain)
    
    private func runEngine(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech, isWhite: Bool) {
        switch stage {
        case .usersTurn:
            handleUsersTurn(speech: speech)
            
        case .processingUserMove:
            executeUserMoveLogic(webView: webView, coordinator: coordinator, speech: speech, isWhite: isWhite)
            
        case .awaitingClarification:
            handleAmbiguityClarification(speech: speech, coordinator: coordinator, isWhite: isWhite)
            
        case .opponentsTurn:
            // Gated until updateTurn() is called by the Scraper
            print("Stage 3: Waiting for Opponent...")
        }
    }

    // MARK: - Stage 1: User's Turn
    
    private func handleUsersTurn(speech: NormalizeSpeech) {
        if speech.firstPiece != "None" && speech.firstSquare != "None" {
            print("Stage 1 -> 2: Speech detected [\(speech.firstPiece) to \(speech.firstSquare)]")
            self.stage = .processingUserMove
        }
    }

    // MARK: - Stage 2: Processing and Execution
    
    private func executeUserMoveLogic(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech, isWhite: Bool) {
        webView.evaluateJavaScript(ChessJSBridge.scrapeScript()) { result, _ in
            guard let dict = result as? [String: Any],
                  let board = dict["board"] as? [[String]],
                  let isWhiteSide = dict["isWhiteSide"] as? Bool else {
                print("⚠️ Scrape failed. Returning to Stage 1.")
                self.stage = .usersTurn
                return
            }
            
            let state = ChessEngine.GameState(board: board, isFlipped: !isWhiteSide)
            guard let targetSquare = self.notationToSquare(speech.firstSquare) else {
                self.resetToStage1(speech: speech, message: "Invalid square")
                return
            }
            
            let pieceChar = self.getPieceChar(speech.firstPiece, isWhite: isWhite)
            let candidates = self.findAllLegalPieces(piece: pieceChar, target: Int(targetSquare) ?? 0, state: state)
            
            if candidates.count == 1 {
                // Stage 2a: Move Legal
                print("Stage 2a: Move Legal. Executing.")
                coordinator.executeMoveScript(from: candidates.first!, to: targetSquare, isWhite: isWhite)
                speech.reset()
                self.stage = .opponentsTurn
            } else if candidates.count > 1 {
                // Stage 4 Transition: Ambiguity Found
                self.ambiguousCandidates = candidates
                self.pendingTargetSquare = targetSquare
                
                self.pieceName = self.expandPieceName(pieceChar)
                let msg = "More than one \(self.pieceName) can move to \(speech.firstSquare). From what square do you want to move?"
                
                print("Stage 2 -> 4: Ambiguity detected.")
                TextToSpeechManager.shared.queueSpeak(msg)
                speech.reset()
                self.stage = .awaitingClarification
            } else {
                // Stage 2b: Not Legal
                print("Stage 2b: No legal move found.")
                self.resetToStage1(speech: speech, message: "Not legal move")
            }
        }
    }

    // MARK: - Stage 4: Clarification (Ambiguity)
    
    private func handleAmbiguityClarification(speech: NormalizeSpeech, coordinator: ChessComWebView.Coordinator, isWhite: Bool) {
        let clarificationSquare = speech.firstSquare
        speech.text = "Starting Square of \(self.pieceName): \(clarificationSquare)"
        if clarificationSquare != "None" {
            guard let clarifiedFrom = self.notationToSquare(clarificationSquare) else {
                speech.reset()
                return
            }
            
            if ambiguousCandidates.contains(clarifiedFrom) {
                print("Stage 4 -> 3: Ambiguity Resolved.")
                coordinator.executeMoveScript(from: clarifiedFrom, to: pendingTargetSquare, isWhite: isWhite)

                self.ambiguousCandidates = []
                self.pendingTargetSquare = ""
                speech.reset()
                self.stage = .opponentsTurn
            } else {
                TextToSpeechManager.shared.queueSpeak("That piece cannot move there. Please say the starting square again.")
                speech.reset()
            }
        }
    }

    // MARK: - Stage 3: Opponent Logic (Triggered by Observer)
    
    func updateTurn(piece: String, from: String, to: String, isWhitePlayer: Bool) {
        let pieceColor = (piece == piece.uppercased()) ? "white" : "black"
        let myColor = isWhitePlayer ? "white" : "black"
        
        if pieceColor != self.lastMovedColor {
            self.lastMovedColor = pieceColor
            let isUserMove = (pieceColor == myColor)
            let fullPieceName = expandPieceName(piece)
            let sentence = isUserMove ? "You moved \(fullPieceName) from \(from) to \(to)" : "\(pieceColor.capitalized) moved \(fullPieceName) from \(from) to \(to)"
            
            TextToSpeechManager.shared.queueSpeak(sentence)

            if !isUserMove {
                print("Stage 3 -> 1: Opponent finished move.")
                self.stage = .usersTurn
            }
        }
    }

    private func resetToStage1(speech: NormalizeSpeech, message: String? = nil) {
        if let msg = message { TextToSpeechManager.shared.queueSpeak(msg) }
        speech.reset()
        self.stage = .usersTurn
    }

    // MARK: - Private Helpers

    private func expandPieceName(_ char: String) -> String {
        let names = ["p": "Pawn", "r": "Rook", "n": "Knight", "b": "Bishop", "q": "Queen", "k": "King"]
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
