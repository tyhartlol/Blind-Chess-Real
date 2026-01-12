import SwiftUI
import FoundationModels
import Speech

struct ContentView: View {
        @State private var input = ""

    var body: some View {
        VStack {
            Text(recorder.transcript)
                .padding()
            Button(recorder.isTranscribing ? "Stop" : "Start") {
                Task {
                    if recorder.isTranscribing {
                        recorder.stopTranscribing()
                    } else {
                        try await recorder.startTranscribing()
                    }
                }
            }
        }
        .padding()
    }
}
