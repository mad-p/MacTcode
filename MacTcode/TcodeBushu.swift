//
//  TcodeBushu.swift
//  MacTcode
//
//  Created by maeda on 2024/05/27.
//

import Cocoa

final class TcodeBushu {
    static let bushu = TcodeBushu()
    
    static var composeTable: [[String]: String] = [:]
    static var decomposeTable: [String: [String]] = [:]
    static var equivTable: [String: String] = [:]

    private init() {
        if let bushuRev = Config.loadConfig(file: "bushu.dic") {
            for line in bushuRev.components(separatedBy: .newlines) {
                let chars = line.map {String($0)}
                if chars.count == 3 {
                    if chars[0] == "N" {
                        TcodeBushu.equivTable[chars[2]] = chars[1]
                    } else {
                        let pair = [chars[0], chars[1]]
                        TcodeBushu.decomposeTable[chars[2]] = pair
                        TcodeBushu.composeTable[pair] = chars[2]
                    }
                } else {
                    NSLog("Invalid bushu.dic entry: \(line)")
                }
            }
        }
    }
    
    func basicCompose(char1: String, char2: String) -> String? {
        return (TcodeBushu.composeTable[[char1, char2]] ??
                TcodeBushu.composeTable[[char2, char1]])
    }
    
    func compose(char1: String, char2: String) -> String? {
        if let ch = basicCompose(char1: char1, char2: char2) {
            return ch
        }
        let ch1 = TcodeBushu.equivTable[char1] ?? char1
        let ch2 = TcodeBushu.equivTable[char2] ?? char2
        if ((ch1 != char1) || (ch2 != char2)) {
            if let ch = basicCompose(char1: ch1, char2: ch2) {
                return ch
            }
        }
        let tc1 = TcodeBushu.decomposeTable[ch1]
        let tc2 = TcodeBushu.decomposeTable[ch2]
        let tc11 = tc1?[0]
        let tc12 = tc1?[1]
        let tc21 = tc2?[0]
        let tc22 = tc2?[1]
        // subtraction
        if (tc11 == ch2) && (tc12 != ch1) && (tc12 != ch2) {
            return tc12
        }
        if (tc12 == ch2) && (tc11 != ch1) && (tc11 != ch2) {
            return tc11
        }
        if (tc21 == ch1) && (tc22 != ch1) && (tc22 != ch2) {
            return tc22
        }
        if (tc22 == ch1) && (tc21 != ch1) && (tc21 != ch2) {
            return tc21
        }
        // parts-wise composition
        for pair in [[ch1, tc22], [ch2, tc11], [ch1, tc21], [ch2, tc12],
                     [tc12, tc22], [tc21, tc12], [tc11, tc22], [tc21, tc11]] {
            let p1 = pair[0]
            let p2 = pair[1]
            if p1 != nil && p2 != nil {
                if let ch = TcodeBushu.bushu.basicCompose(char1: p1!, char2: p2!) {
                    if (ch != ch1) && (ch != ch2) {
                        return ch
                    }
                }
            }
        }
        // new subtraction
        if (tc11 != nil) && (tc11 == tc21) && (tc12 != ch1) && (tc12 != ch2) {
            return tc12
        }
        if (tc11 != nil) && (tc11 == tc22) && (tc12 != ch1) && (tc12 != ch2) {
            return tc12
        }
        if (tc12 != nil) && (tc12 == tc21) && (tc11 != ch1) && (tc11 != ch2) {
            return tc11
        }
        if (tc12 != nil) && (tc12 == tc22) && (tc11 != ch1) && (tc11 != ch2) {
            return tc11
        }
        // not found
        return nil
    }
}
