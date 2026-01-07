//
//  TextToSpeechManager.swift
//  Blind Chess
//
//  Created by Tyler Hartman on 1/7/26.
//

import Foundation
import AVFoundation

class TextToSpeechManager {
    static let shared = TextToSpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        // Use a high-quality voice if available
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-GB.Daniel") ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        // Fix muffled audio by forcing High-Bandwidth mode
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker])
        try? session.setActive(true)

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
    
    
    func testMultipleVoices() {
        // 1. Get all English voices
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.contains("en") }
        
        // 2. Take the first 10
        let testVoices = Array(allVoices.prefix(10))
        
        for (index, voice) in testVoices.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index * 3)) {
                let utterance = AVSpeechUtterance(string: "Voice number \(index + 1). Moving Pawn to Echo 4.")
                utterance.voice = voice
                utterance.rate = 0.5
                
                // 🛠 ADDED LINE BELOW: This prints the exact ID you need to hardcode
                print("🎤 [\(index + 1)] Name: \(voice.name) | ID: \(voice.identifier) | Quality: \(voice.quality.rawValue)")
                
                self.synthesizer.speak(utterance)
            }
        }
    }
}


/*
 
 func speak(_ text: String) {
     let utterance = AVSpeechUtterance(string: text)
     
     // 1. Get all voices that are English (US)
     let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
     
     // 2. Find Grandpa specifically within that English list
     if let grandpa = englishVoices.first(where: { $0.name.contains("Grandpa") }) {
         utterance.voice = grandpa
         print("🎯 Found English Grandpa: \(grandpa.identifier)")
     } else {
         // Fallback to a standard clear English voice if Grandpa is missing
         print("⚠️ Grandpa not found in English list. Falling back to Samantha.")
         utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
     }
     
     utterance.pitchMultiplier = 0.9
     utterance.volume = 1.0
     utterance.rate = 0.45
     
     // Ensure high-quality audio routing
     let session = AVAudioSession.sharedInstance()
     try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker])
     
     synthesizer.stopSpeaking(at: .immediate)
     synthesizer.speak(utterance)
 }
 
 */
