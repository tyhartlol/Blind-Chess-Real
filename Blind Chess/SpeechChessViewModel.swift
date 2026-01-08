import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechChessViewModel: ObservableObject {
    @Published var transcript: String = ""
    @Published var piece: String = "none"
    @Published var move: String = "none"
    @Published var pendingMoveCommand: ChessMove?
    
    var isPlayingWhite: Bool = true
    private var isProcessing = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init() {
        // Clear UI when the bot starts speaking
        TextToSpeechManager.shared.onSpeechStatusChanged = { [weak self] isSpeaking in
            if isSpeaking {
                Task { @MainActor in
                    print("Stopping mic.")
                    self?.stopListening()
                }
            } else {
                print("✅ Bot finished: Restarting clean session...")
                self?.isProcessing = false
                try? self?.startListening()
                Task { @MainActor in self?.isProcessing = false }
            }
        }

        // Hard reset after a move is successfully made in the WebView
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ClearMoveUI"), object: nil, queue: .main) { _ in
            self.hardResetAfterMove()
        }
    }

    func requestPermissions() async {
        await SFSpeechRecognizer.requestAuthorization { _ in }
        await AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func startListening() throws {
        stopListening()
        isProcessing = false
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .mixWithOthers])
        try audioSession.setActive(true)
        
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request!) { result, error in
            if self.isProcessing || TextToSpeechManager.shared.synthesizer.isSpeaking {
                self.transcript = ""
                return
            }

            guard let result = result else { return }
            let text = result.bestTranscription.formattedString.lowercased()
            self.transcript = text
            self.parseSpeech(text)
        }
    }

    private func parseSpeech(_ text: String) {
        let replacements = ["night": "knight", "nite": "knight", "ponde": "pawn", "ha": "h8", "to": " "]
        var normalized = text
        for (k, v) in replacements { normalized = normalized.replacingOccurrences(of: k, with: v) }

        let piecesList = ["pawn", "knight", "bishop", "rook", "queen", "king"]
        let foundPiece = piecesList.last(where: { normalized.contains($0) }) ?? "none"
        
        var foundSquare = "none"
        let files = "abcdefgh", ranks = "12345678"
        for f in files {
            for r in ranks {
                let sq = "\(f)\(r)"
                if normalized.contains(sq) { foundSquare = sq }
            }
        }

        self.piece = foundPiece
        self.move = foundSquare

        // Handoff to ChessGameManager
        if foundPiece != "none" && foundSquare != "none" && !isProcessing {
            if let cmd = ChessGameManager.shared.createMoveCommand(
                piece: foundPiece,
                square: foundSquare,
                isWhite: isPlayingWhite
            ) {
                self.isProcessing = true
                self.pendingMoveCommand = cmd
            }
        }
    }

    func hardResetAfterMove() {
        stopListening()
        self.transcript = ""
        self.piece = "none"
        self.move = "none"
        self.pendingMoveCommand = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            try? self.startListening()
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
    }
}
