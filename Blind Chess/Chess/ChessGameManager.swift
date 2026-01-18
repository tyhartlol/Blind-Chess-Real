import Foundation
import WebKit
import SwiftUI

enum GameStage {
    case usersTurn
    case processingUserMove
    case awaitingClarification
    case opponentsTurn
}

class ChessGameManager {
    static let shared = ChessGameManager()
    private let engine = ChessEngine()
    
    private var stage: GameStage = .usersTurn
    private var lastMovedColor: String = "black"
    private var ambiguousCandidates: [String] = []
    private var pendingTargetSquare: String = ""
    private var castlingTimeoutTimer: Timer?
    
    // Castling State
    private var isAttemptingCastle: Bool = false
    private var castleSide: String = ""
    
    var pieceName : String = ""
    private var playerIsWhite: Bool = true

    func start(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech, isWhite: Bool) {
        self.playerIsWhite = isWhite
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.runEngine(webView: webView, coordinator: coordinator, speech: speech)
        }
    }
    
    func setPlayerColor(isWhite: Bool) {
        if self.playerIsWhite != isWhite {
            print("Manager Sync: Switching color to \(isWhite ? "White" : "Black")")
            self.playerIsWhite = isWhite
        }
    }

    private func runEngine(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech) {
        switch stage {
        case .usersTurn:
            handleUsersTurn(speech: speech)
        case .processingUserMove:
            executeUserMoveLogic(webView: webView, coordinator: coordinator, speech: speech)
        case .awaitingClarification:
            handleAmbiguityClarification(speech: speech, coordinator: coordinator)
        case .opponentsTurn:
            break
        }
    }

    private func handleUsersTurn(speech: NormalizeSpeech) {
        if (speech.firstPiece != "None" && speech.firstSquare != "None") || speech.castlingSide != "None" {
            self.stage = .processingUserMove
        }
    }

    private func executeUserMoveLogic(webView: WKWebView, coordinator: ChessComWebView.Coordinator, speech: NormalizeSpeech) {
        webView.evaluateJavaScript(ChessJSBridge.scrapeScript()) { result, _ in
            guard let dict = result as? [String: Any],
                  let board = dict["board"] as? [[String]] else {
                self.stage = .usersTurn
                return
            }
            
            let isWhiteSide = (dict["isWhiteSide"] as? Int == 1) || (dict["isWhiteSide"] as? Bool == true)
            let state = ChessEngine.GameState(board: board, isFlipped: !isWhiteSide)

            // --- CASTLING EXECUTION ---
            if speech.castlingSide != "None" {
                self.isAttemptingCastle = true
                self.castleSide = speech.castlingSide
                
                let fromSq = self.playerIsWhite ? "51" : "58"
                let toSq: String
                if self.playerIsWhite {
                    toSq = (speech.castlingSide == "Kingside") ? "71" : "31"
                } else {
                    toSq = (speech.castlingSide == "Kingside") ? "78" : "38"
                }
                
                coordinator.executeMoveScript(from: fromSq, to: toSq, isWhite: self.playerIsWhite)
                self.startCastlingTimeout(speech: speech)
                speech.reset()
                self.stage = .opponentsTurn
                return
            }

            // --- STANDARD MOVE ---
            guard let targetSquare = self.notationToSquare(speech.firstSquare) else {
                self.resetToStage1(speech: speech, message: "Invalid square")
                return
            }
            
            let pieceChar = self.getPieceChar(speech.firstPiece, isWhite: self.playerIsWhite)
            let candidates = self.findAllLegalPieces(piece: pieceChar, target: Int(targetSquare) ?? 0, state: state)
            
            if candidates.count == 1 {
                coordinator.executeMoveScript(from: candidates.first!, to: targetSquare, isWhite: self.playerIsWhite)
                speech.reset()
                self.stage = .opponentsTurn
            } else if candidates.count > 1 {
                self.ambiguousCandidates = candidates
                self.pendingTargetSquare = targetSquare
                self.pieceName = self.expandPieceName(pieceChar)
                TextToSpeechManager.shared.queueSpeak("Multiple \(self.pieceName)s can move there. From what square?")
                speech.reset()
                self.stage = .awaitingClarification
            } else {
                self.resetToStage1(speech: speech, message: "Illegal move")
            }
        }
    }

    private func handleAmbiguityClarification(speech: NormalizeSpeech, coordinator: ChessComWebView.Coordinator) {
        if speech.firstSquare != "None" {
            guard let clarifiedFrom = self.notationToSquare(speech.firstSquare) else { return }
            if ambiguousCandidates.contains(clarifiedFrom) {
                coordinator.executeMoveScript(from: clarifiedFrom, to: pendingTargetSquare, isWhite: self.playerIsWhite)
                speech.reset()
                self.stage = .opponentsTurn
            } else {
                TextToSpeechManager.shared.queueSpeak("That piece cannot move there.")
                speech.reset()
            }
        }
    }

    func updateTurn(piece: String, from: String, to: String, isWhitePlayer: Bool) {
        castlingTimeoutTimer?.invalidate()
        
        let pieceColor = (piece == piece.uppercased()) ? "white" : "black"
        let myColor = self.playerIsWhite ? "white" : "black"
        
        if pieceColor != self.lastMovedColor {
            self.lastMovedColor = pieceColor
            let isUserMove = (pieceColor == myColor)
            let name = expandPieceName(piece)
            
            let sentence: String
            if isUserMove && isAttemptingCastle {
                sentence = "You castled \(castleSide)"
                isAttemptingCastle = false
            } else {
                sentence = isUserMove ? "You moved \(name) to \(to)" : "\(pieceColor.capitalized) moved \(name) to \(to)"
            }
            
            TextToSpeechManager.shared.queueSpeak(sentence)
            if !isUserMove { self.stage = .usersTurn }
        }
    }

    private func startCastlingTimeout(speech: NormalizeSpeech) {
        castlingTimeoutTimer?.invalidate()
        castlingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            if self.isAttemptingCastle {
                self.isAttemptingCastle = false
                self.resetToStage1(speech: speech, message: "Cannot Castle")
            }
        }
    }

    private func resetToStage1(speech: NormalizeSpeech, message: String? = nil) {
        if let msg = message { TextToSpeechManager.shared.queueSpeak(msg) }
        speech.reset()
        self.stage = .usersTurn
    }

    // Helpers
    func indicesToNotation(row: Int, col: Int) -> String {
        let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
        return "\(files[col])\(8 - row)"
    }

    private func notationToSquare(_ notation: String) -> String? {
        let clean = notation.lowercased().trimmingCharacters(in: .whitespaces)
        let files: [String: Int] = ["a":1,"b":2,"c":3,"d":4,"e":5,"f":6,"g":7,"h":8]
        guard clean.count == 2, let f = files[String(clean.prefix(1))] else { return nil }
        return "\(f)\(clean.suffix(1))"
    }

    private func getPieceChar(_ name: String, isWhite: Bool) -> String {
        let mapping = ["pawn":"p", "rook":"r", "knight":"n", "night":"n", "bishop":"b", "queen":"q", "king":"k"]
        let char = mapping[name.lowercased()] ?? "p"
        return isWhite ? char.uppercased() : char.lowercased()
    }

    private func expandPieceName(_ char: String) -> String {
        let names = ["p": "Pawn", "r": "Rook", "n": "Knight", "b": "Bishop", "q": "Queen", "k": "King"]
        return names[char.lowercased()] ?? "Piece"
    }

    private func findAllLegalPieces(piece: String, target: Int, state: ChessEngine.GameState) -> [String] {
        var found = [String]()
        for r in 0...7 {
            for c in 0...7 where state.board[r][c] == piece {
                let sq = (c + 1) * 10 + (8 - r)
                if engine.isMoveLegal(state: state, piece: piece, start: sq, end: target) { found.append("\(sq)") }
            }
        }
        return found
    }
}
