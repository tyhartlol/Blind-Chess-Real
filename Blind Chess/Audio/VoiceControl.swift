import SwiftUI
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    
    static let shared = SpeechRecognizer()
    
    private init() {}
    
    @Published var transcript: String = ""
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startTranscribing() {
        // 1. Request Authorization
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.setupAndStart()
                } else {
                    self.transcript = "Permission denied"
                }
            }
        }
    }

    private func setupAndStart() {
        // Reset existing tasks
        
        if audioEngine.isRunning { return }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    print(self.transcript)
                }
            }
            
            // Only handle errors if they aren't related to a normal shutdown
            if error != nil {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                print("Recognition stopped or encountered an error: \(String(describing: error))")
            }
        }
    }

    func stopTranscribing() {
        // 1. Tell the request to stop accepting new audio
        recognitionRequest?.endAudio()
        
        // 2. Remove the microphone tap
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 3. Stop the engine and reset the request
        audioEngine.stop()
        
        // 4. Invalidate the task safely
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
    }
}
