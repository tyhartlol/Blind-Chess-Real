//
//  ChessJSBridge.swift
//  Blind Chess
//
//  Created by Tyler Hartman on 1/7/26.
//

import Foundation
struct ChessJSBridge {
    static func injectionScript() -> String {
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

        return css
    }

    static func scrapeScript() -> String {

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
        return js
    }

    static func moveScript(from: String, to: String, isWhite: Bool) -> String {
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
        return js
    }
    
    static func touchScript(at square: String, isWhite: Bool) -> String {
        let js = """
        (function() {
            const board = document.querySelector('chess-board') || document.querySelector('.board');
            if (!board) return 'JS ERR: Board not found';

            const boardRect = board.getBoundingClientRect();
            const squareSize = boardRect.width / 8;
            const isWhitePerspective = \(isWhite);

            const sq = parseInt("\(square)");
            const file = Math.floor(sq / 10);
            const rank = sq % 10;

            let visualFile, visualRank;
            if (isWhitePerspective) {
                visualFile = file - 1;
                visualRank = 8 - rank;
            } else {
                visualFile = 8 - file;
                visualRank = rank - 1;
            }

            const x = boardRect.left + (visualFile * squareSize) + (squareSize / 2);
            const y = boardRect.top + (visualRank * squareSize) + (squareSize / 2);

            // Dispatch events directly to whatever is at those coordinates (the promotion menu)
            const target = document.elementFromPoint(x, y);
            if (target) {
                const evOpts = { bubbles: true, clientX: x, clientY: y, pointerType: 'touch', view: window };
                target.dispatchEvent(new PointerEvent('pointerdown', evOpts));
                target.dispatchEvent(new PointerEvent('pointerup', evOpts));
                target.click();
                return 'JS OK: Touched ' + \(square);
            }
            return 'JS ERR: No target at coords';
        })();
        """
        return js
    }
}
