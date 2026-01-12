import SwiftUI
import Foundation

struct ContentView: View {
    // Shared instances ensure everyone is looking at the same data
    @ObservedObject var recognizer = SpeechRecognizer.shared
    @StateObject private var normalizer = NormalizeSpeech()
    
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                Text("Detected Piece")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(normalizer.firstPiece.capitalized)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
            }
            .padding(40)
            .background(Circle().fill(Color.blue.opacity(0.05)))

            VStack(alignment: .leading, spacing: 10) {
                Text("Live Transcript")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(recognizer.transcript)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxHeight: 200)
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
            }

            Button(action: {
                isRecording.toggle()
                if isRecording {
                    // Start fresh
                    recognizer.transcript = ""
                    normalizer.reset()
                    recognizer.startTranscribing()
                } else {
                    recognizer.stopTranscribing()
                    // Reset normalizer logic for the next session
                    normalizer.reset()
                }
            }) {
                HStack {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(isRecording ? Color.red : Color.blue)
                .cornerRadius(15)
            }
            .shadow(radius: isRecording ? 0 : 5)
        }
        .padding(30)
    }
}
