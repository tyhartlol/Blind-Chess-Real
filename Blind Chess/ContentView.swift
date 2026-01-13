import SwiftUI

struct ContentView: View {
    @StateObject private var normalizer = NormalizeSpeech()
    @ObservedObject var recognizer = SpeechRecognizer.shared
    @State private var isPlayingWhite: Bool = true
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 15) {
            VStack {
                Text(normalizer.text)
                    .font(.system(.title3, design: .monospaced))
                    .bold()
                Text(recognizer.transcript.isEmpty ? "Microphone Standby" : recognizer.transcript)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            ChessComWebView(url: URL(string: "https://www.chess.com/play/computer")!, isPlayingWhite: $isPlayingWhite, normalizer: normalizer)
                .cornerRadius(12)
                .padding(.horizontal)

            Button(action: {
                isRecording.toggle()
                if isRecording {
                    SpeechRecognizer.shared.startTranscribing()
                } else {
                    SpeechRecognizer.shared.stopTranscribing()
                }
            }) {
                HStack {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    Text(isRecording ? "Listening" : "Start Voice")
                }
                .font(.headline)
                .frame(width: 200, height: 50)
                .background(isRecording ? Color.red : Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .padding(.bottom)
        }
    }
}
