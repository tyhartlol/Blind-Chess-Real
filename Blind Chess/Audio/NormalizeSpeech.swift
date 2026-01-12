import Foundation
import Combine

class NormalizeSpeech: ObservableObject {
    @Published var firstPiece: String = "None"
    
    private var lastProcessedLength = 0
    private var hasFoundFirstPiece = false
    private var cancellables = Set<AnyCancellable>()
    private let chessPieces = ["pawn", "knight", "bishop", "rook", "queen", "king"]

    init() {
        // 1. Watch the transcript for the "First Piece" logic
        SpeechRecognizer.shared.$transcript
            .receive(on: RunLoop.main)
            .sink { [weak self] newTranscript in
                self?.processTranscript(newTranscript)
            }
            .store(in: &cancellables)
            
        // 2. IMPORTANT: Automatically reset when the transcript is cleared or recording stops
        SpeechRecognizer.shared.$transcript
            .filter { $0.isEmpty }
            .sink { [weak self] _ in
                self?.reset()
            }
            .store(in: &cancellables)
    }

    private func processTranscript(_ fullTranscript: String) {
        // If empty, reset and wait
        if fullTranscript.isEmpty {
            reset()
            return
        }
        
        // If we already found the first piece for this specific session, stop looking
        guard !hasFoundFirstPiece else { return }

        let words = fullTranscript.lowercased().components(separatedBy: .whitespacesAndNewlines)

        if let foundWord = words.first(where: { word in
            chessPieces.contains { piece in word.contains(piece) }
        }) {
            self.hasFoundFirstPiece = true
            self.firstPiece = foundWord
            print("Found first piece of this session: \(foundWord)")
        }
    }

    func reset() {
        lastProcessedLength = 0
        hasFoundFirstPiece = false
        // We don't necessarily clear firstPiece here so it stays on screen
        // until the NEXT piece is found, but you can set to "None" if preferred.
    }
}
