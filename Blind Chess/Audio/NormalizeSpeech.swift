//import Foundation
//import Speech
//
//struct NormalizeSpeech {
//    
//    static func generateChessModel() async -> URL? {
//        let fileManager = FileManager.default
//        
//        // Switch to Documents directory for better cross-process access
//        guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            return nil
//        }
//        
//        // Use a simple name without subdirectories to reduce complexity
//        let url = docsDir.appendingPathComponent("ChessMoves.lmdata")
//
//        do {
//            if fileManager.fileExists(atPath: url.path) {
//                try fileManager.removeItem(at: url)
//            }
//            
//            let modelData = SFCustomLanguageModelData(
//                locale: Locale(identifier: "en-US"),
//                identifier: "com.chess.voice",
//                version: "1.0"
//            ) {
//                let pieces = ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
//                for piece in pieces { SFCustomLanguageModelData.PhraseCount(phrase: piece, count: 10) }
//                
//                for f in ["a", "b", "c", "d", "e", "f", "g", "h"] {
//                    for r in 1...8 { SFCustomLanguageModelData.PhraseCount(phrase: "\(f)\(r)", count: 20) }
//                }
//            }
//
//            try await modelData.export(to: url)
//            
//            // Give the OS a heartbeat to register the file on disk
//            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//            
//            print("Model successfully exported to: \(url.path)")
//            return url
//        } catch {
//            print("Export error: \(error)")
//            return nil
//        }
//    }
//
//    static func formatMove(rawText: String) -> (piece: String, move: String) {
//        let text = rawText.lowercased()
//        var piece = "None"
//        var move = "None"
//        
//        let pieces = ["pawn", "knight", "bishop", "rook", "queen", "king"]
//        if let foundPiece = pieces.first(where: { text.contains($0) }) {
//            piece = foundPiece.capitalized
//        }
//        
//        if let range = text.range(of: "[a-h][1-8]", options: .regularExpression) {
//            move = String(text[range])
//        }
//        
//        return (piece, move)
//    }
//}
