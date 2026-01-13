import Foundation
import Combine

class NormalizeSpeech: ObservableObject {
    // This is the single variable your ContentView will now display
    @Published var text: String = "Piece: None  |  Square: None"
    
    // Internal state tracking
    @Published var firstPiece: String = "None"
    @Published var firstSquare: String = "None"
    private var hasFoundFirstPiece = false
    private var hasFoundFirstSquare = false
    private var cancellables = Set<AnyCancellable>()
    
    private let chessPieces = ["pawn", "knight", "bishop", "rook", "queen", "king"]
    
    private let phoneticMap: [String: String] = [
        "alpha": "a", "alfa": "a", "bravo": "b", "charlie": "c", "delta": "d",
        "echo": "e", "foxtrot": "f", "golf": "g", "hotel": "h",
        "night": "knight", "pond": "pawn", "born": "pawn", "porn": "pawn",
        "look": "rook", "ha": "h8"
    ]

    init() {
        SpeechRecognizer.shared.$transcript
            .receive(on: RunLoop.main)
            .sink { [weak self] newTranscript in
                self?.processTranscript(newTranscript)
            }
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

        if !hasFoundFirstPiece {
            if let piece = getPiece(from: cleaned) {
                self.firstPiece = piece.capitalized
                self.hasFoundFirstPiece = true
                changed = true
            }
        }

        if !hasFoundFirstSquare {
            if let square = getSquare(from: cleaned) {
                self.firstSquare = square.uppercased()
                self.hasFoundFirstSquare = true
                changed = true
            }
        }

        // Only update the published string if we actually found something new
        if changed {
            updateDisplayText()
        }
    }

    // Combine the findings into the specific format you requested
    private func updateDisplayText() {
        self.text = "Piece: \(firstPiece)  |  Square: \(firstSquare)"
    }

    // MARK: - Extractor Functions

    private func getPiece(from text: String) -> String? {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.first { word in
            chessPieces.contains { piece in word.contains(piece) }
        }
    }

    private func getSquare(from text: String) -> String? {
        let pattern = "\\b([a-h])([1-8])\\b|\\b([a-h])\\s+([1-8])\\b"
        if let range = text.range(of: pattern, options: .regularExpression) {
            let matched = String(text[range])
            return matched.replacingOccurrences(of: " ", with: "")
        }
        return nil
    }

    private func applyPhoneticFixes(to text: String) -> String {
        var words = text.components(separatedBy: .whitespacesAndNewlines)
        for (index, word) in words.enumerated() {
            if let correction = phoneticMap[word] {
                words[index] = correction
            }
        }
        return words.joined(separator: " ")
    }

    func reset() {
        hasFoundFirstPiece = false
        hasFoundFirstSquare = false
        firstPiece = "None"
        firstSquare = "None"
        updateDisplayText()
    }
}
