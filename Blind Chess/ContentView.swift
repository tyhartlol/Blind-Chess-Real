import SwiftUI

struct ContentView: View {
    @StateObject private var vm = SpeechChessViewModel()
    @State private var webMoveTrigger: ChessMove?
    @State private var isPlayingWhite = true

    var body: some View {
        VStack(spacing: 16) {
            // 1. Transcript Display
            VStack(alignment: .leading) {
                Text(vm.transcript.isEmpty ? "Listening..." : vm.transcript)
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.yellow)
                    .font(.system(.body, design: .monospaced))
                    .cornerRadius(12)
            }
            
            // 2. Parsed Move Status
            HStack(spacing: 6) {
                Text("Piece: \(vm.piece.capitalized)  |")
                Text("Move: \(vm.move.uppercased())")
            }
            .font(.title3)
            .bold()
            
            // 3. Chess.com Web View
            ChessComWebView(
                url: URL(string: "https://www.chess.com/play/computer")!,
                moveCommand: $webMoveTrigger,
                isPlayingWhite: $isPlayingWhite
            )
            .frame(height: UIScreen.main.bounds.height * 0.55)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3))
            )
            
            // 4. Controls
            HStack(spacing: 20) {
                Button("START") {
                    Task { try? vm.startListening() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("STOP") {
                    vm.stopListening()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding()
        // Sync the player side to the ViewModel
        .onChange(of: isPlayingWhite) { _, newValue in
            vm.isPlayingWhite = newValue
        }
        // When the VM generates a command via ChessGameManager, trigger the WebView
        .onChange(of: vm.pendingMoveCommand) { _, newCommand in
            if let cmd = newCommand {
                self.webMoveTrigger = cmd
            }
        }
        .task {
            await vm.requestPermissions()
        }
    }
}
