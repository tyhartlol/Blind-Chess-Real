import Foundation
import AVFoundation

class TextToSpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TextToSpeechManager()
    let synthesizer = AVSpeechSynthesizer()
    var onSpeechStatusChanged: ((Bool) -> Void)?
    
    // The list to hold pending speech strings
    private var speechQueue: [String] = []
    // Tracks if we are currently mid-speech to avoid overlapping
    private var isProcessingQueue = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Public function to add text to the queue
    func queueSpeak(_ text: String) {
        speechQueue.append(text)
        print("📢 Queued: \(text) (Total in queue: \(speechQueue.count))")
        
        // If not already speaking, start the process
        if !isProcessingQueue {
            processNextInQueue()
        }
    }

    /// Internal helper to pull the next string and speak it
    private func processNextInQueue() {
        guard !speechQueue.isEmpty else {
            isProcessingQueue = false
            return
        }

        isProcessingQueue = true
        let nextText = speechQueue.first! // Get the first item
        speak(nextText)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-GB.Daniel") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5

        let session = AVAudioSession.sharedInstance()
        // Note: .playback is often more reliable for TTS than .videoChat unless you need the mic simultaneously
        try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker])
        try? session.setActive(true)

        // Note: Removed stopSpeaking(at: .immediate) here so it doesn't kill the queue flow
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onSpeechStatusChanged?(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Done Speaking: \(utterance.speechString)")
        
        // 1. Remove the item that just finished
        if !speechQueue.isEmpty {
            speechQueue.removeFirst()
        }
        
        // 2. Notify system
        onSpeechStatusChanged?(false)
        
        // 3. Move to next item
        processNextInQueue()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isProcessingQueue = false
        onSpeechStatusChanged?(false)
    }
}
