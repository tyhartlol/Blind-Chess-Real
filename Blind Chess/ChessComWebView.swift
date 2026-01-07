import SwiftUI
import WebKit

// 1. The Data Model
struct ChessMove {
    let from: String
    let to: String
}

// 2. The Web View Component
struct ChessComWebView: UIViewRepresentable {
    let url: URL
    @Binding var moveCommand: ChessMove?
    @Binding var isPlayingWhite: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }
    
    

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let move = moveCommand {
            // 🏁 1. First, detect the current side/color
            context.coordinator.fetchCurrentBoardState { state in
                guard let state = state else { return }
                
                // 🔄 Update the binding immediately
                let currentSideIsWhite = !state.isFlipped
                DispatchQueue.main.async {
                    self.isPlayingWhite = currentSideIsWhite
                }
                
                // 2. Now proceed with the move logic using the fresh state
                var finalFrom: String? = nil
                let engine = ChessEngine()
                let targetInt = Int(move.to) ?? 0

                if move.from.contains("FIND:") {
                    // Determine the correct case based on the FRESHLY detected side
                    let pieceName = move.from.replacingOccurrences(of: "FIND:", with: "")
                    // If we detected White side, search for Uppercase. If Black, search for Lowercase.
                    let pieceToFind = currentSideIsWhite ? pieceName.uppercased() : pieceName.lowercased()
                    
                    print("🔍 SEARCHING: Looking for legal '\(pieceToFind)' (User is \(currentSideIsWhite ? "White" : "Black"))")
                    
                    outerLoop: for r in 0...7 {
                        for c in 0...7 {
                            let pieceOnBoard = state.board[r][c]
                            if pieceOnBoard == pieceToFind {
                                let currentSquare = (c + 1) * 10 + (8 - r)
                                if engine.isMoveLegal(state: state, piece: pieceOnBoard, start: currentSquare, end: targetInt) {
                                    finalFrom = "\(currentSquare)"
                                    break outerLoop
                                }
                            }
                        }
                    }
                } else {
                    finalFrom = move.from
                }

                if let from = finalFrom {
                    let pieceName = move.from.replacingOccurrences(of: "FIND:", with: "")
                    announceMove(pieceCode: pieceName, fromSquare: from, targetSquare: move.to)
//                    TextToSpeechManager.shared.testMultipleVoices()
                    context.coordinator.executeMove(from: from, to: move.to)
                } else {
                    TextToSpeechManager.shared.speak("No legal \(move.from) can reach \(move.to)") // 🔊 Announce error
                }
            }
            
            DispatchQueue.main.async { moveCommand = nil }
        }
    }
    
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self) // ⬅️ CHANGE THIS: Pass 'self'
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ChessComWebView
        weak var webView: WKWebView?
        
        init(parent: ChessComWebView) {
            self.parent = parent
        }
        
        // ➕ ADD THIS METHOD
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let css = """
            (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                    /* Hide the top navigation and ads to save space */
                    #cc-header, .nav-container, .board-layout-ad { display: none !important; }
                    
                    /* Force the main container to take full width */
                    .board-layout-main {
                        width: 100% !important;
                        margin: 0 !important;
                        padding: 0 !important;
                        display: block !important;
                    }

                    /* Make the board itself fill the width */
                    chess-board, .board {
                        width: 98vw !important;
                        height: 98vw !important;
                        margin: 0 auto !important;
                    }
                    
                    /* Ensure the page is still scrollable */
                    body, html {
                        overflow-y: auto !important;
                        height: auto !important;
                    }
                `;
                document.head.appendChild(style);
                
                // Scroll to the board automatically after it loads
                setTimeout(() => {
                    const board = document.querySelector('chess-board') || document.querySelector('.board');
                    if (board) board.scrollIntoView({block: "center"});
                }, 500);
            })();
            """
            webView.evaluateJavaScript(css)
        }

        func executeMove(from: String, to: String) {
            // Pass the current orientation to the JS
            let isWhite = self.parent.isPlayingWhite
            
            let js = """
            (function() {
                const board = document.querySelector('chess-board') || document.querySelector('.board');
                if (!board) return 'JS ERR: Board not found';

                const boardRect = board.getBoundingClientRect();
                const squareSize = boardRect.width / 8;
                const isWhite = \(isWhite); // 👈 Dynamically injected

                function getCoords(squareStr) {
                    const sq = parseInt(squareStr);
                    const file = Math.floor(sq / 10);
                    const rank = sq % 10;
                    
                    let visualFile, visualRank;

                    if (isWhite) {
                        // White perspective: File 1 is left, Rank 8 is top
                        visualFile = file - 1;
                        visualRank = 8 - rank;
                    } else {
                        // Black perspective: File 8 is left, Rank 1 is top
                        visualFile = 8 - file;
                        visualRank = rank - 1;
                    }

                    const x = boardRect.left + (visualFile * squareSize) + (squareSize / 2);
                    const y = boardRect.top + (visualRank * squareSize) + (squareSize / 2);
                    return { x, y };
                }

                const start = getCoords("\(from)");
                const end = getCoords("\(to)");

                // ... rest of your event dispatching logic (pointerdown/up)
                const piece = document.querySelector('.piece.square-\(from)');
                if (!piece) return 'JS ERR: Piece .square-\(from) not found';

                const downEv = { bubbles: true, clientX: start.x, clientY: start.y, pointerType: 'touch' };
                piece.dispatchEvent(new PointerEvent('pointerdown', downEv));
                piece.dispatchEvent(new PointerEvent('pointerup', downEv));

                setTimeout(() => {
                    const moveEv = { bubbles: true, clientX: end.x, clientY: end.y, pointerType: 'touch' };
                    const target = document.elementFromPoint(end.x, end.y) || board;
                    target.dispatchEvent(new PointerEvent('pointerdown', moveEv));
                    target.dispatchEvent(new PointerEvent('pointerup', moveEv));
                    target.click();
                }, 250);

                return 'JS OK: Moving ' + \(from) + ' to ' + \(to) + ' (Flipped: ' + !isWhite + ')';
            })();
            """
           
            webView?.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("⚠️ JS ERROR: \(error.localizedDescription)")
                } else {
                    print("💻 JS RESPONSE: \(result ?? "nil")")
                }
            }
        }
        
        func printBoard(_ board: [[String]]) {
            print("\n--- SCRAPED BOARD ---")
            print("   1   2   3   4   5   6   7   8")
            for (idx, row) in board.enumerated() {
                let rankNum = 8 - idx
                let rowString = row.map { $0 == "" ? "." : $0 }.joined(separator: " | ")
                print("\(rankNum) | \(rowString) |")
            }
            print("---------------------\n")
        }
    }
}

// MARK: - Extensions for Scraping
extension ChessComWebView.Coordinator {
    
    func fetchCurrentBoardState(completion: @escaping (ChessEngine.GameState?) -> Void) {
        let js = """
        (function() {
            let board = Array(8).fill(null).map(() => Array(8).fill(""));
            const pieces = document.querySelectorAll('.piece');
            
            const firstCoordinate = document.querySelector('text.coordinate-light, text.coordinate-dark');
                    let isWhiteSide = true;
                    if (firstCoordinate && firstCoordinate.textContent === '1') {
                        isWhiteSide = false;
                    }
        
            pieces.forEach(p => {
                const classes = p.className.split(' ');
                let type = "";
                let squareClass = "";
                
                classes.forEach(c => {
                    if (c.length === 2 && (c[0] === 'w' || c[0] === 'b')) type = c;
                    if (c.startsWith('square-')) squareClass = c;
                });
                
                if (type && squareClass) {
                    const coords = squareClass.replace('square-', '');
                    const file = parseInt(coords[0]) - 1;
                    const rank = 8 - parseInt(coords[1]);
                    
                    let pieceChar = type[1];
                    if (type[0] === 'w') pieceChar = pieceChar.toUpperCase();
                    
                    if (rank >= 0 && rank < 8 && file >= 0 && file < 8) {
                        board[rank][file] = pieceChar;
                    }
                }
            });
            return { board: board, isWhiteSide: isWhiteSide };
        })();
        """
        
        webView?.evaluateJavaScript(js) { result, error in
            guard let dict = result as? [String: Any],
                  let board = dict["board"] as? [[String]],
                  let isWhiteSide = dict["isWhiteSide"] as? Bool else {
                completion(nil)
                return
            }
            
            print("👤 USER IS PLAYING AS: \(isWhiteSide ? "WHITE" : "BLACK")")
            // Note: We initialize with default castling rights.
            // In a real game, you'd track these based on previous moves.
            let state = ChessEngine.GameState(
                board: board,
                isFlipped: !isWhiteSide,
                whiteCanCastleKingside: true,
                whiteCanCastleQueenside: true,
                blackCanCastleKingside: true,
                blackCanCastleQueenside: true,
                enPassantTarget: nil
            )
            completion(state)
        }
    }
}


func announceMove(pieceCode: String, fromSquare: String, targetSquare: String) {
    // 1. Convert Piece Code (e.g., "FIND:p") -> "Pawn"
    let code = pieceCode.replacingOccurrences(of: "FIND:", with: "").lowercased()
    let pieceMap = ["p":"Pawn", "r":"Rook", "n":"Knight", "b":"Bishop", "q":"Queen", "k":"King"]
    let pieceName = pieceMap[code] ?? "Piece"
    
    // 2. Mapping helper
    let files = ["", "a", "b", "c", "d", "e", "f", "g", "h"]
    
    // 3. Helper to convert "52" -> "e2"
    func toNotation(_ square: String) -> String {
        guard square.count == 2 else { return square }
        let fileDigit = Int(String(square.first!)) ?? 0
        let rankDigit = String(square.last!)
        if fileDigit >= 1 && fileDigit <= 8 {
            return "\(files[fileDigit])\(rankDigit)"
        }
        return square
    }
    
    // 4. Translate both squares
    let fromNotation = toNotation(fromSquare)
    let targetNotation = toNotation(targetSquare)
    
    // 5. Build and Speak
    let text = "Moving \(pieceName) from \(fromNotation) to \(targetNotation)"
    
    print("🔊 Speaking: \(text)")
    TextToSpeechManager.shared.speak(text)
}
