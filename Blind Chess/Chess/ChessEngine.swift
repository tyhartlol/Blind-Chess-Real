//import Foundation
//
//struct ChessEngine {
//    
//    struct GameState {
//        var board: [[String]]
//        var isFlipped: Bool = false
//        var whiteCanCastleKingside: Bool = true
//        var whiteCanCastleQueenside: Bool = true
//        var blackCanCastleKingside: Bool = true
//        var blackCanCastleQueenside: Bool = true
//        var enPassantTarget: Int?
//    }
//
//    func isMoveLegal(state: GameState, piece: String, start: Int, end: Int) -> Bool {
//        let isWhite = piece == piece.uppercased()
//        
//        // Convert "52" (e2) to array indices
//        // Logic: Rank 1 is bottom (index 7), File 1 is left (index 0)
//        let sR = 8 - (start % 10), sC = (start / 10) - 1
//        let eR = 8 - (end % 10), eC = (end / 10) - 1
//        
//        guard sR >= 0, sR < 8, sC >= 0, sC < 8, eR >= 0, eR < 8, eC >= 0, eC < 8 else { return false }
//
//        // 1. Geometry check
//        guard canPieceReach(state: state, piece: piece, sR: sR, sC: sC, eR: eR, eC: eC) else {
//            return false
//        }
//        
//        // 2. King safety (Simulation)
//        let tempState = simulateMove(state: state, sR: sR, sC: sC, eR: eR, eC: eC)
//        if isKingInCheck(state: tempState, whiteKing: isWhite) {
//            return false
//        }
//        
//        return true
//    }
//
//    private func canPieceReach(state: GameState, piece: String, sR: Int, sC: Int, eR: Int, eC: Int) -> Bool {
//        let rowDiff = eR - sR
//        let colDiff = eC - sC
//        let target = state.board[eR][eC]
//        let isWhite = piece == piece.uppercased()
//
//        if target != "" && (target == target.uppercased()) == isWhite { return false }
//
//        switch piece.lowercased() {
//        case "p":
//            let direction = isWhite ? -1 : 1
//            let startRow = isWhite ? 6 : 1
//            if colDiff == 0 && target == "" && rowDiff == direction { return true }
//            if colDiff == 0 && target == "" && sR == startRow && rowDiff == 2 * direction {
//                return state.board[sR + direction][sC] == ""
//            }
//            if abs(colDiff) == 1 && rowDiff == direction && target != "" { return true }
//            return false
//        case "r":
//            return (sR == eR || sC == eC) && isPathClear(sR, sC, eR, eC, state.board)
//        case "n":
//            return (abs(rowDiff) == 2 && abs(colDiff) == 1) || (abs(rowDiff) == 1 && abs(colDiff) == 2)
//        case "b":
//            return abs(rowDiff) == abs(colDiff) && isPathClear(sR, sC, eR, eC, state.board)
//        case "q":
//            return (sR == eR || sC == eC || abs(rowDiff) == abs(colDiff)) && isPathClear(sR, sC, eR, eC, state.board)
//        case "k":
//            return abs(rowDiff) <= 1 && abs(colDiff) <= 1
//        default: return false
//        }
//    }
//
//    private func isPathClear(_ sR: Int, _ sC: Int, _ eR: Int, _ eC: Int, _ board: [[String]]) -> Bool {
//        let rStep = (eR - sR).signum()
//        let cStep = (eC - sC).signum()
//        var currR = sR + rStep
//        var currC = sC + cStep
//        while currR != eR || currC != eC {
//            if board[currR][currC] != "" { return false }
//            currR += rStep
//            currC += cStep
//        }
//        return true
//    }
//
//    private func isKingInCheck(state: GameState, whiteKing: Bool) -> Bool {
//        let kingChar = whiteKing ? "K" : "k"
//        var kR = -1, kC = -1
//        for r in 0...7 {
//            for c in 0...7 {
//                if state.board[r][c] == kingChar { kR = r; kC = c; break }
//            }
//        }
//        if kR == -1 { return false }
//        for r in 0...7 {
//            for c in 0...7 {
//                let p = state.board[r][c]
//                if p != "" && (p == p.uppercased()) != whiteKing {
//                    if canPieceReach(state: state, piece: p, sR: r, sC: c, eR: kR, eC: kC) { return true }
//                }
//            }
//        }
//        return false
//    }
//
//    private func simulateMove(state: GameState, sR: Int, sC: Int, eR: Int, eC: Int) -> GameState {
//        var newState = state
//        newState.board[eR][eC] = newState.board[sR][sC]
//        newState.board[sR][sC] = ""
//        return newState
//    }
//}
//
//extension Int {
//    func signum() -> Int { self > 0 ? 1 : (self < 0 ? -1 : 0) }
//}
