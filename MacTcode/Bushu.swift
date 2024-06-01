//
//  TcodeBushu.swift
//  MacTcode
//
//  Created by maeda on 2024/05/27.
//

// 部首変換アルゴリズム
// tc-bushu.el の初期バージョンのアルゴリズムを再現。
// 元コードはGPLだが、コードコピーはしていないので、MITライセンスで配布できるはず。

import Cocoa
import InputMethodKit

final class Bushu {
    static let i = Bushu()
    
    private var composeTable: [[String]: String] = [:]
    private var decomposeTable: [String: [String]] = [:]
    private var equivTable: [String: String] = [:]

    func readDictionary() {
        NSLog("Read bushu dictionary...")
        composeTable = [:]
        decomposeTable = [:]
        equivTable = [:]
        if let bushuDic = Config.loadConfig(file: "bushu.dic") {
            for line in bushuDic.components(separatedBy: .newlines) {
                let chars = line.map {String($0)}
                if chars.count == 3 {
                    if chars[0] == "N" {
                        equivTable[chars[2]] = chars[1]
                    } else {
                        let pair = [chars[0], chars[1]]
                        decomposeTable[chars[2]] = pair
                        composeTable[pair] = chars[2]
                    }
                } else {
                    if line.count > 0 {
                        NSLog("Invalid bushu.dic entry: \(line)")
                    }
                }
            }
        }
        NSLog("\(composeTable.count) bushu entries read")
    }
    
    private init() {
        readDictionary()
    }
    
    func basicCompose(char1: String, char2: String) -> String? {
        return (composeTable[[char1, char2]] ??
                composeTable[[char2, char1]])
    }
    
    func compose(char1: String, char2: String) -> String? {
        if let ch = basicCompose(char1: char1, char2: char2) {
            return ch
        }
        let ch1 = equivTable[char1] ?? char1
        let ch2 = equivTable[char2] ?? char2
        if ((ch1 != char1) || (ch2 != char2)) {
            if let ch = basicCompose(char1: ch1, char2: ch2) {
                return ch
            }
        }
        let tc1 = decomposeTable[ch1]
        let tc2 = decomposeTable[ch2]
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
                if let ch = basicCompose(char1: p1!, char2: p2!) {
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

class PostfixBushuAction: Action {
    func execute(client: MyInputText) -> Command {
        // postfix bushu
        let cursor = client.selectedRange()
        var ch1: String? = nil
        var ch2: String? = nil
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)

        if (cursor.length == 0 && cursor.location >= 2) || cursor.length == 2 {
            // bushu henkan from selection or previous two chars
            let location = if cursor.length == 2 {
                cursor.location
            } else {
                cursor.location - 2
            }
            if let text = client.string(from: NSRange(location: location, length: 2), actualRange: &replaceRange) {
                let chars = text.map { String($0) }
                ch1 = chars[0]
                ch2 = chars[1]
                if (ch1 != nil) && (ch2 != nil) {
                    NSLog("Bushu \(ch1!)\(ch2!)")
                }
            }
        }
        /* take chars from recent
        else {
        */
        if (ch1 == nil) || (ch2 == nil) {
            NSLog("Bushu henkan: no input")
        } else {
            if let ch = Bushu.i.compose(char1: ch1!, char2: ch2!) {
                NSLog("Bushu \(ch1!)\(ch2!) -> \(ch)")
                client.insertText(ch, replacementRange: cursor)
            } else {
                NSLog("Bushu henkan no candidates for \(ch1!)\(ch2!)")
            }
        }
        return .processed
    }
}
