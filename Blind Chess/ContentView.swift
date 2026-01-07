import SwiftUI

struct ContentView: View {
    
    @StateObject private var vm = SpeechChessViewModel()
    @State private var moveCommand: ChessMove?
    
    @State private var isPlayingWhite = true
    
    @State private var selectedPiece = "P" // Default to White Pawn
    @State private var destinationString = "e4"
    
    let pieces = [
        ("Pawn", "P"), ("Rook", "R"), ("Knight", "N"),
        ("Bishop", "B"), ("Queen", "Q"), ("King", "K")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            
            // 1️⃣ Transcript
            VStack(alignment: .leading) {
                
                
                Text(vm.transcript.isEmpty ? "Listening..." : vm.transcript)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
            }
            
            // 2️⃣ Parsed move
            HStack(spacing: 6) {
                Text("Piece: \(vm.piece)  |")
                Text("Move: \(vm.move)")
            }
            .font(.title3)
            
            HStack(spacing: 16) {
                Picker("Piece", selection: $selectedPiece) {
                    ForEach(pieces, id: \.1) { Text($0.0).tag($0.1) }
                }
                .pickerStyle(.menu)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                                    
                TextField("e4", text: $destinationString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .autocapitalization(.none)
                
                Button("Move") {
                    handleManualMove()
                }
                .buttonStyle(.borderedProminent)
                
                Button("e2 -> e4") {
                    moveCommand = ChessMove(from: "52", to: "54")
                }
            }
            
            
            ChessComWebView(
                url: URL(string: "https://www.chess.com/play/computer")!,
                moveCommand: $moveCommand, isPlayingWhite: $isPlayingWhite
            )
            .frame(height: UIScreen.main.bounds.height * 0.55)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3))
            )
            
            // 4️⃣ Controls
            HStack(spacing: 16) {
                
                Button("Start") {
                    Task { try? vm.startListening() }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Stop") {
                    vm.stopListening()
                }
                .buttonStyle(.bordered)
                
            }
            
        }
        .padding()
        
        .onChange(of: vm.move) { oldValue, newValue in
            if newValue != "none" {
                handleVoiceMove(target: newValue)
            }
        }
        
        .task {
            await vm.requestPermissions()
        }
    }
    
    
    func handleVoiceMove(target: String) {
        let spokenPiece = vm.piece.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Determine color based on your current setup
        // You could also add a Toggle in the UI for "isPlayingWhite"
        
        let pieceMapping: [String: String] = [
            "pawn": isPlayingWhite ? "P" : "p",
            "rook": isPlayingWhite ? "R" : "r",
            "knight": isPlayingWhite ? "N" : "n",
            "night": isPlayingWhite ? "N" : "n",
            "bishop": isPlayingWhite ? "B" : "b",
            "queen": isPlayingWhite ? "Q" : "q",
            "king": isPlayingWhite ? "K" : "k"
        ]
        
        guard let pieceChar = pieceMapping[spokenPiece] else { return }
        
        if let targetSquare = notationToSquare(target) {
            moveCommand = ChessMove(from: "FIND:\(pieceChar)", to: targetSquare)
        }
    }
    
    func handleManualMove() {
            // Convert "e4" -> "54"
        guard let target = notationToSquare(destinationString) else {
            print("Invalid Destination")
            return
        }
        
        // We set the moveCommand.
        // Note: In ChessComWebView, we will add logic to find the 'from'
        // based on the 'selectedPiece' provided.
        // For now, we signal the move.
        moveCommand = ChessMove(from: "FIND:\(selectedPiece)", to: target)
    }
    
    func notationToSquare(_ notation: String) -> String? {
        let n = notation.lowercased()
        guard n.count == 2 else { return nil }
        let files = ["a":1, "b":2, "c":3, "d":4, "e":5, "f":6, "g":7, "h":8]
        guard let f = files[String(n.first!)], let r = n.last?.wholeNumberValue else { return nil }
        return "\(f)\(r)"
    }
}

