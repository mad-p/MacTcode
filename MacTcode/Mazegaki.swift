//
//  Mazegaki.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

// 交ぜ書き変換アルゴリズム
// tc-mazegaki.el の割と新しいバージョンのアルゴリズムを再現。
// 元コードはGPLだが、コードコピーはしていないので、MITライセンスで配布できるはず。

import Cocoa
import InputMethodKit

final class MazegakiDict {
    static let i = MazegakiDict()
    
    var dict: [String: String] = [:]
    static let inflectionMark = "—"
    
    func readDictionary() {
        NSLog("Read mazegaki dictionary...")
        dict = [:]
        if let mazedic = Config.loadConfig(file: "mazegaki.dic") {
            for line in mazedic.components(separatedBy: .newlines) {
                let kv = line.components(separatedBy: " ")
                if kv.count == 2 {
                    dict[kv[0]] = kv[1]
                } else {
                    if line.count > 0 {
                        NSLog("Invalid mazegaki.dic line: \(line)")
                    }
                }
            }
        }
        NSLog("\(dict.count) mazegaki entries read")
    }
    
    private init() {
        readDictionary()
    }
}

class MazegakiHit {
    var found: Bool = false // 見つかったかどうか
    var key: String = ""    // dictを見るときのキー
    var length: Int = 0     // 読みの長さ
    var offset: Int = 0     // 活用部分の長さ
    
    func candidates() -> [String] {
        if !found {
            return []
        }
        if let dictEntry = MazegakiDict.i.dict[key] {
            var cand = dictEntry.components(separatedBy: "/")
            if cand.isEmpty {
                return []
            }
            cand = cand.filter({ $0 != ""})
            return cand
        }
        return []
    }
}

class Mazegaki {
    static var maxInflection = 4 // 活用部分の最大長
    static var inflectionCharsMin = 0x3041 // 活用部分に許される文字コードポイントの下限
    static var inflectionCharsMax = 0x30fe // 活用部分に許される文字上限
    static var nonYomiCharacters =
        ["、", "。", "，", "．", "・", "「", "」", "（", "）"] // 読み部分に許されない文字
    
    let yomi: [String] // 読み部分の文字列、各要素は1文字
    let inflection: Bool // 活用語をさがすかどうか
    let fixed: Bool // 読み長さが固定かどうか
    let max: Int // 読みの最大長さ。fixedの場合はyomiの長さと同じ
    
    init(_ text: String, inflection: Bool, fixed: Bool) {
        yomi = text.map { String($0) }
        let l = yomi.count
        var m = l
        for i in 0..<yomi.count {
            if Mazegaki.nonYomiCharacters.contains(yomi[l - i - 1]) {
                m = i
                break
            }
        }
        self.max = m
        self.inflection = inflection
        self.fixed = fixed
    }
    
    // 検索キーを文字列として返す
    func key(_ i: Int, offset: Int = 0) -> String? {
        if i > yomi.count || i == 0 || offset >= i {
            return nil
        }
        var chars = yomi.suffix(i)
        if offset > 0 && chars.count > offset {
            chars = chars.dropLast(offset)
            chars.append(MazegakiDict.inflectionMark)
        }
        if chars.count > 0 {
            return chars.joined()
        } else {
            return nil
        }
    }
    
    // max文字以内かつ候補がある最大長さの読みを見つける
    // 活用しないバージョン
    // from:に前回のヒット結果が指定された場合、それよりも短い読みをさがす
    func find(_ from: MazegakiHit?) -> MazegakiHit? {
        let result = MazegakiHit()
        result.found = false
        var i = from != nil ? from!.length - 1 : max
        while i > 0 {
            if fixed && i != max {
                return result
            }
            if let k = key(i) {
                if MazegakiDict.i.dict[k] != nil {
                    result.key = k
                    result.length = i
                    result.found = true
                    result.offset = 0
                    return result
                }
            }
            i -= 1
        }
        return result
    }
}

class PostfixMazegakiAction: Action {
    let maxYomi = 10
    let inflection : Bool
    init(inflection: Bool) {
        self.inflection = inflection
    }
    func execute(client: Client, mode: Mode, controller: Controller) -> Command {
        let cursor = client.selectedRange()
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)
        
        var mazegaki: Mazegaki
        
        if cursor.length == 0 {
            // mazegaki henkan from recentChars
            let (startPos, length) = if cursor.location >= maxYomi {
                (cursor.location - maxYomi, maxYomi)
            } else {
                (0, cursor.location)
            }
            if let text = client.string(from: NSRange(location: startPos, length: length), actualRange: &replaceRange) {
                NSLog("Online mazegaki from \(text)")
                mazegaki = Mazegaki(text, inflection: inflection, fixed: false)
            } else {
                NSLog("No yomi")
                return .processed
            }
        } else {
            // mazegaki henkan from selection
            if let text = client.string(from: cursor, actualRange: &replaceRange) {
                NSLog("Offline mazegaki \(text)")
                mazegaki = Mazegaki(text, inflection: inflection, fixed: true)
            } else {
                return .processed
            }
        }
        
        let hit = mazegaki.find(nil)
        if hit == nil {
            return .processed
        }
        let candidates = hit!.candidates()
        if candidates.isEmpty {
            return .processed
        }

        let inputLength = hit!.length
        var target: NSRange
        if cursor.length > 0 {
            target = cursor
        } else {
            let (location, length) = if cursor.location >= inputLength {
                (cursor.location - inputLength, inputLength)
            } else {
                (0, NSNotFound)
            }
            target = NSRange(location: location, length: length)
        }
        if candidates.count == 1 {
            let string = candidates.first!
            NSLog("Mazegaki: sole candidate: \(string)")
            client.insertText(string, replacementRange: target)
        } else {
            NSLog("Mazegaki: more than one candidates: \(candidates)")
        }
        return .processed
    }
}

class MazegakiSelectionMode: Mode, ModeWithCandidates {
    let mazegaki: Mazegaki
    var hit: MazegakiHit? = nil
    let controller: Controller
    let target: NSRange
    let candidateWindow: IMKCandidates
    init(controller: Controller, mazegaki: Mazegaki!, target: NSRange) {
        self.controller = controller
        self.mazegaki = mazegaki
        self.target = target
        self.candidateWindow = controller.candidateWindow
        candidateWindow.show()
    }
    func handle(_ inputEvent: InputEvent, client: (any Client)!, controller: any Controller) -> Bool {
        switch inputEvent.type {
        case .printable, .enter, .left, .right, .up, .down, .space:
            if let event = inputEvent.event {
                candidateWindow.interpretKeyEvents([event])
            }
            return true
        case .delete, .escape:
            cancel()
            return true
        case .control_punct, .unknown:
            return true
        }
    }
    
    func cancel() {
        candidateWindow.hide()
        controller.popMode()
    }
    func reset() {
    }
    
    func candidates(_ sender: Any!) -> [Any]! {
        hit = mazegaki.find(hit)
        if hit == nil {
            cancel()
            return []
        } else {
            return hit!.candidates()
        }
    }
    
    func candidateSelected(_ candidateString: NSAttributedString!, client: (any Client)!) {
        client.insertText(candidateString.string, replacementRange: target)
        cancel()
    }
    
    func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        
    }
    
    
}
