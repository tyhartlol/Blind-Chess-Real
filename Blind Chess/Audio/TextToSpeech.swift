import Foundation
import AVFoundation

class TextToSpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TextToSpeechManager()
    let synthesizer = AVSpeechSynthesizer()
    
    var onSpeechStatusChanged: ((Bool) -> Void)?
    
    private var speechQueue: [String] = []
    private var isProcessingQueue = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func queueSpeak(_ text: String) {
        speechQueue.append(text)
        if !isProcessingQueue {
            processNextInQueue()
        }
    }

    private func processNextInQueue() {
        guard !speechQueue.isEmpty else {
            isProcessingQueue = false
            return
        }

        isProcessingQueue = true
        let nextText = speechQueue.first!
        speak(nextText)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-GB.Daniel") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 1.0

        let session = AVAudioSession.sharedInstance()
        do {
            // .mixWithOthers prevents the mic from killing the speaker
            try session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("❌ TTS Session Error: \(error)")
        }

        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("📢 Start Speaking: \(utterance.speechString)")
        onSpeechStatusChanged?(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ Done Speaking: \(utterance.speechString)")
        
        if !speechQueue.isEmpty {
            speechQueue.removeFirst()
        }
        
        // ONLY signal Mic On (false) if there are no more sentences waiting
        if speechQueue.isEmpty {
            isProcessingQueue = false
            onSpeechStatusChanged?(false)
        } else {
            // Immediately start the next move announcement
            processNextInQueue()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onSpeechStatusChanged?(false)
        isProcessingQueue = false
    }
}
