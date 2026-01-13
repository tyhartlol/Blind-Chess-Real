import Foundation
import AVFoundation

class TextToSpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = TextToSpeechManager()
    let synthesizer = AVSpeechSynthesizer()
    var onSpeechStatusChanged: ((Bool) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        // High-clarity British voice
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-GB.Daniel") ?? AVSpeechSynthesisVoice(language: "en-US")
        // Increased rate for faster game flow
        utterance.rate = 0.55
        utterance.pitchMultiplier = 1.0
        
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onSpeechStatusChanged?(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onSpeechStatusChanged?(false)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onSpeechStatusChanged?(false)
    }
}
