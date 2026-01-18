import Foundation
import Combine

class NormalizeSpeech: ObservableObject {
    @Published var text: String = "Piece: None  |  Square: None"
    @Published var firstPiece: String = "None"
    @Published var firstSquare: String = "None"
    @Published var castlingSide: String = "None"
    
    private var hasFoundFirstPiece = false
    private var hasFoundFirstSquare = false
    private var cancellables = Set<AnyCancellable>()
    
    private let chessPieces = ["pawn", "knight", "bishop", "rook", "queen", "king"]
    private let phoneticMap: [String: String] = [
        "alpha": "a", "alfa": "a", "bravo": "b", "charlie": "c", "delta": "d",
        "echo": "e", "foxtrot": "f", "golf": "g", "hotel": "h",
        "night": "knight", "pond": "pawn", "born": "pawn", "porn": "pawn",
        "look": "rook", "ha": "h8",
        "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
        "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10"
    ]

    init() {
        SpeechRecognizer.shared.$transcript
            .receive(on: RunLoop.main)
            .sink { [weak self] newTranscript in self?.processTranscript(newTranscript) }
            .store(in: &cancellables)
            
        SpeechRecognizer.shared.$transcript
            .filter { $0.isEmpty }
            .sink { [weak self] _ in self?.reset() }
            .store(in: &cancellables)
    }

    private func processTranscript(_ fullTranscript: String) {
        guard !fullTranscript.isEmpty else { return }
        let cleaned = applyPhoneticFixes(to: fullTranscript.lowercased())
        var changed = false

        if let side = getCastlingSide(from: cleaned) {
            self.castlingSide = side
            changed = true
        }

        if castlingSide == "None" {
            if !hasFoundFirstPiece, let piece = getPiece(from: cleaned) {
                self.firstPiece = piece.capitalized
                self.hasFoundFirstPiece = true
                changed = true
            }
            if !hasFoundFirstSquare, let square = getSquare(from: cleaned) {
                self.firstSquare = square.uppercased()
                self.hasFoundFirstSquare = true
                changed = true
            }
        }
        if changed { updateDisplayText() }
    }

    func updateDisplayText() {
        self.text = (castlingSide != "None") ? "Action: Castle \(castlingSide)" : "Piece: \(firstPiece)  |  Square: \(firstSquare)"
    }

    private func getCastlingSide(from text: String) -> String? {
        guard text.contains("castle") || text.contains("castling") else { return nil }
        return (text.contains("queenside") || text.contains("queen")) ? "Queenside" : "Kingside"
    }

    private func getPiece(from text: String) -> String? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.first { word in chessPieces.contains { piece in word.contains(piece) } }
    }

    private func getSquare(from text: String) -> String? {
        let pattern = "\\b([a-h])([1-8])\\b|\\b([a-h])\\s+([1-8])\\b"
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range]).replacingOccurrences(of: " ", with: "")
        }
        return nil
    }

    private func applyPhoneticFixes(to text: String) -> String {
        var words = text.components(separatedBy: .whitespacesAndNewlines)
        for (index, word) in words.enumerated() {
            if let correction = phoneticMap[word] { words[index] = correction }
        }
        return words.joined(separator: " ")
    }

    func reset() {
        hasFoundFirstPiece = false; hasFoundFirstSquare = false
        firstPiece = "None"; firstSquare = "None"; castlingSide = "None"
        updateDisplayText()
    }
}
