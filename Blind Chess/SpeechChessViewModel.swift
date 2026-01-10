import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechChessViewModel: ObservableObject {
    @Published var transcript: String = ""
    @Published var piece: String = "none"
    @Published var move: String = "none"
    @Published var pendingMoveCommand: ChessMove?
    
    // Stores [targetSquare, pieceChar] when the manager finds 2+ pieces
    @Published var disambiguationContext: [String: String]? = nil
    
    var isPlayingWhite: Bool = true
    private var isProcessing = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    init() {
        print("🛠 ViewModel Initialized")
        
        TextToSpeechManager.shared.onSpeechStatusChanged = { [weak self] isSpeaking in
            if isSpeaking {
                print("🔈 Bot speaking... stopping mic.")
                Task { @MainActor in self?.stopListening() }
            } else {
                print("🎤 Bot finished. Restarting Mic...")
                self?.isProcessing = false
                try? self?.startListening()
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ClearMoveUI"), object: nil, queue: .main) { _ in
            print("🧹 Resetting UI state")
            self.hardResetAfterMove()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("RequireDisambiguation"), object: nil, queue: .main) { note in
            print("🚨 DISAMBIGUATION NOTIFICATION RECEIVED")
            if let info = note.object as? [String: String] {
                self.disambiguationContext = info
                self.isProcessing = false
            }
        }
    }

    func requestPermissions() async {
        await SFSpeechRecognizer.requestAuthorization { _ in }
        await AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func startListening() throws {
        // 1. Ensure a clean slate
        stopListening()
        
        // Small delay to let hardware reset
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        isProcessing = false
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { result, error in
            if let error = error {
                print("❌ Speech Error: \(error.localizedDescription)")
                // If we hit a 1101 or similar, reset hardware
                if (error as NSError).code == 1101 {
                    self.hardResetAfterMove()
                }
                return
            }

            if self.isProcessing || TextToSpeechManager.shared.synthesizer.isSpeaking {
                return
            }

            guard let result = result else { return }
            let text = result.bestTranscription.formattedString.lowercased()
            self.transcript = text
            self.parseSpeech(text)
        }
    }

    private func parseSpeech(_ text: String) {
        if text.isEmpty { return }
        print("📢 SPEECH TRACE: [\(text)]")

        let replacements = ["night": "knight", "nite": "knight", "ponde": "pawn", "to": " ", "at": " ", "see": "c"]
        var normalized = text
        for (k, v) in replacements { normalized = normalized.replacingOccurrences(of: k, with: v) }

        // Mode A: Resolve Ambiguity
        if let context = disambiguationContext {
            print("⚖️ Evaluating Disambiguation Input: \(normalized)")
            resolveDisambiguation(normalized, context: context)
            return
        }

        // Mode B: Standard Parsing
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

        if foundPiece != "none" && foundSquare != "none" && !isProcessing {
            if let cmd = ChessGameManager.shared.createMoveCommand(piece: foundPiece, square: foundSquare, isWhite: isPlayingWhite) {
                print("🚀 Standard Move Created: \(cmd.from) to \(cmd.to)")
                self.isProcessing = true
                self.pendingMoveCommand = cmd
            }
        }
    }

    private func resolveDisambiguation(_ text: String, context: [String: String]) {
        let fileMap = [
            "a":"1", "b":"2", "c":"3", "d":"4",
            "e":"5", "f":"6", "g":"7", "h":"8"
        ]
        let rankList = ["1", "2", "3", "4", "5", "6", "7", "8"]
        
        var modifier: String? = nil
        
        for (fName, fVal) in fileMap {
            if text.contains(fName) { modifier = fVal; break }
        }
        
        if modifier == nil {
            for r in rankList {
                if text.contains(r) { modifier = r; break }
            }
        }
        
        if let mod = modifier {
            let piece = context["piece"]!
            let target = context["target"]!
            
            print("✅ Resolved! Modifier: \(mod). Sending Filtered Command.")
            self.pendingMoveCommand = ChessMove(from: "FILTER:\(piece):\(mod)", to: target)
            self.disambiguationContext = nil
            self.isProcessing = true
        } else {
            print("❓ Modifier not found in: \(text)")
        }
    }

    func hardResetAfterMove() {
        stopListening()
        self.transcript = ""
        self.piece = "none"
        self.move = "none"
        self.pendingMoveCommand = nil
        self.disambiguationContext = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            try? self.startListening()
        }
    }

    func stopListening() {
        print("🛑 Stopping Mic Safely")
        task?.finish() // Tell the task to finish instead of just canceling
        task = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        request = nil
    }
}
