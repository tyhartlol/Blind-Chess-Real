import AVFoundation
import Foundation
import Speech

// Swift concurrency wrappers for old APIs
extension SFSpeechRecognizer {
    /// Request and report authorization to perform speech recognition.
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    /// Request and report permission to record audio.
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

/// A lightweight speech-to-text service built on `SFSpeechRecognizer`.
final class VoiceControl {
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

    /// Initialize with a specific locale (defaults to device locale).
    init(localeIdentifier: String = Locale.current.identifier) {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    deinit { reset() }

    @discardableResult
    func authorize() async -> Bool {
        let speechOK = await SFSpeechRecognizer.hasAuthorizationToRecognize()
        let micOK = await AVAudioSession.sharedInstance().hasPermissionToRecord()
        return speechOK && micOK
    }

    @MainActor
    func transcribe() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let recognizer = self.recognizer else {
                        throw NSError(domain: "SpeechToTextService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported locale or recognizer unavailable."])
                    }
                    guard recognizer.isAvailable else {
                        throw NSError(domain: "SpeechToTextService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is currently unavailable."])
                    }

                    let (engine, request) = try Self.prepareEngine()
                    self.audioEngine = engine
                    self.request = request

                    self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                        guard let self else { return }

                        if let error = error {
                            continuation.finish(throwing: error)
                            self.reset()
                            return
                        }

                        guard let result = result else { return }

                        // Emit the current best transcription (includes partials when shouldReportPartialResults = true in prepareEngine())
                        continuation.yield(result.bestTranscription.formattedString)

                        if result.isFinal {
                            continuation.finish()
                            self.reset()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                    self.reset()
                }
            }
        }
    }

    func stopTranscribing() {
        request?.endAudio()
        reset()
    }

    private func reset() {
        task?.cancel()
        task = nil
        request = nil
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) } catch { }
    }

    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        // Uncomment if you want to force on-device when available:
        // request.requiresOnDeviceRecognition = true

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()
        return (engine, request)
    }
}
