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
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-GB.Daniel") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker])
        try? session.setActive(true)

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onSpeechStatusChanged?(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Done Speaking.")
        onSpeechStatusChanged?(false)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onSpeechStatusChanged?(false)
    }
}
