import SwiftUI

struct ContentView: View {
    @StateObject private var normalizer = NormalizeSpeech()
    @ObservedObject var recognizer = SpeechRecognizer.shared
    @State private var isPlayingWhite: Bool = true
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 20) {
            VStack {
                Text(normalizer.text).font(.headline).padding(.top)
                Text(isRecording ? "Listening..." : "Mic Paused")
                    .font(.caption)
                    .foregroundColor(isRecording ? .green : .red)
            }

            ChessComWebView(url: URL(string: "https://www.chess.com/classroom")!, isPlayingWhite: $isPlayingWhite, normalizer: normalizer)
                .cornerRadius(12).padding(.horizontal)

            Button(action: {
                isRecording.toggle()
            }) {
                HStack {
                    Image(systemName: isRecording ? "mic.fill" : "mic.slash.fill")
                    Text(isRecording ? "Stop Mic" : "Start Mic")
                }
                .bold()
                .frame(width: 200, height: 50)
                .background(isRecording ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        // Modern iOS 17+ Syntax
        .onChange(of: isRecording) { oldValue, newValue in
            if newValue {
                SpeechRecognizer.shared.startTranscribing()
            } else {
                SpeechRecognizer.shared.stopTranscribing()
            }
        }
        .onAppear {
            TextToSpeechManager.shared.onSpeechStatusChanged = { isSpeaking in
                DispatchQueue.main.async {
                    if isSpeaking {
                        // Kill mic immediately when speech starts
                        self.isRecording = false
                    } else {
                        // Wait 0.7s after speech ends to avoid the echo/feedback loop
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            // Final check: Only turn mic on if the queue didn't get a new move
                            if !TextToSpeechManager.shared.synthesizer.isSpeaking {
                                self.isRecording = true
                            }
                        }
                    }
                }
            }
        }
    }
}
