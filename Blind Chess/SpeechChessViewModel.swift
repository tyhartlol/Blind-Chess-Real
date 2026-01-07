import Foundation
import Speech
import AVFoundation
import SwiftUI

@MainActor
class SpeechChessViewModel: ObservableObject {

    // UI state
    @Published var transcript: String = ""
    @Published var piece: String = "none"
    @Published var move: String = "none"

    // Speech
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // MARK: - Permissions
    func requestPermissions() async {
        await SFSpeechRecognizer.requestAuthorization { _ in }
        await AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    // MARK: - Start Listening
    func startListening() throws {

        stopListening()

        transcript = ""
        piece = "none"
        move = "none"

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord,
                                     mode: .videoChat, // 'videoChat' has better quality than 'measurement' or 'voiceChat'
                                     options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try audioSession.setActive(true)
        
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) {
            buffer, _ in
            self.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request!) { result, error in
            guard let result = result else { return }

            let text = result.bestTranscription.formattedString.lowercased()
            self.transcript = text
            self.parseChess(from: text)
        }
    }

    // MARK: - Stop
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
    }

    // MARK: - Chess Parsing
    private func parseChess(from text: String) {

        // Normalize speech quirks
        let replacements: [String: String] = [
            "night": "knight",
            "nite": "knight",
            "ponde": "pawn",
            "rookie": "rook",
            "to": " ",
            "two": "2",
            "for": "4",
            "ha" : "h8"
        ]

        var normalized = text
        for (k, v) in replacements {
            normalized = normalized.replacingOccurrences(of: k, with: v)
        }

        // Detect piece
        let pieces = ["pawn", "knight", "bishop", "rook", "queen", "king"]
        piece = pieces.first(where: { normalized.contains($0) }) ?? "none"

        // Detect square (a1–h8)
        let files = "abcdefgh"
        let ranks = "12345678"

        for f in files {
            for r in ranks {
                let square = "\(f)\(r)"
                if normalized.contains(square) {
                    move = square
                    return
                }
            }
        }

        move = "none"
    }
}
