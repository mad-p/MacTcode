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

/// 特定の読み、活用部分に対応する候補全体を表わす
class MazegakiHit {
    var yomi: [String] = []
    var found: Bool = false // 見つかったかどうか
    var key: String = ""    // dictを見るときのキー
    var length: Int = 0     // 読みの長さ
    var offset: Int = 0     // 活用部分の長さ
    
    func candidates() -> [String] {
        if !found {
            return []
        }
        if let dictEntry = MazegakiDict.i.dict[key] {
            let inflection = yomi.suffix(offset).joined()
            var cand = dictEntry.components(separatedBy: "/")
            if cand.isEmpty {
                return []
            }
            cand = cand.filter({ $0 != ""})
            cand = cand.map { $0 + inflection }
            return cand
        }
        return []
    }
    func duplicate() -> MazegakiHit {
        var newHit = MazegakiHit()
        newHit.yomi = yomi
        newHit.found = found
        newHit.key = key
        newHit.length = length
        newHit.offset = offset
        return newHit
    }
}

class Mazegaki {
    static var maxInflection = 4 // 活用部分の最大長
    static var inflectionCharsMin = 0x3041 // 活用部分に許される文字コードポイントの下限
    static var inflectionCharsMax = 0x30fe // 活用部分に許される文字上限
    static var inflectionRange = inflectionCharsMin...inflectionCharsMax
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
            let infChars = chars.suffix(offset)
            if !infChars.allSatisfy({
                let charCode = $0.unicodeScalars.first!.value
                return Mazegaki.inflectionRange.contains(Int(charCode))
            }) {
                return nil
            }
            chars = chars.dropLast(offset)
            chars.append(MazegakiDict.inflectionMark)
        }
        if chars.count > 0 {
            let res: String = chars.joined()
            NSLog("Mazegaki.key: yomi=\(yomi.joined())  i=\(i)  offset=\(offset) ->  result=\(res)")
            return res
        } else {
            return nil
        }
    }
    
    /// max文字以内かつ候補がある最大長さの読みを見つける
    /// from:に前回のヒット結果が指定された場合、それよりも短い読みをさがす
    func find(_ from: MazegakiHit?) -> MazegakiHit {
        // 活用しないとき
        // - 最大長さを見つける
        // 活用するとき
        // - 全体の長さが同じときに、活用部分の長さが短い順で全部見つける
        let result = MazegakiHit()
        result.found = false
        var i: Int
        var offset: Int
        if inflection {
            // 活用あり
            // 前回と同じyomiで、ひとつ長いoffsetから始める
            i = from != nil ? from!.length : max
            offset = from != nil ? from!.offset + 1 : 1
        } else {
            i = from != nil ? from!.length - 1 : max
            offset = 0
        }
    outerloop:
        while i > 0 {
            defer { i -= 1 }
            if fixed && i != max {
                return result
            }
            var j = offset
            offset = (inflection ? 1 : 0) // 次回のiループでのj初期値
            
            while j <= Mazegaki.maxInflection {
                defer { j += 1 }
                if !inflection && j > 0 {
                    continue outerloop
                }
                
                if let k = key(i, offset: j) {
                    if MazegakiDict.i.dict[k] != nil {
                        result.yomi = yomi.suffix(i)
                        result.key = k
                        result.length = i
                        result.found = true
                        result.offset = j
                        return result
                    }
                }
            }
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
        let candidates = hit.candidates()
        if candidates.isEmpty {
            return .processed
        }

        let inputLength = hit.length
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
        if !inflection && candidates.count == 1 {
            let string = candidates.first!
            NSLog("Mazegaki: sole candidate: \(string)")
            client.insertText(string, replacementRange: target)
        } else {
            let newMode = MazegakiSelectionMode(controller: controller, mazegaki: mazegaki, target: target)
            controller.pushMode(newMode)
            newMode.showWindow()
            NSLog("Mazegaki: more than one candidates: \(candidates)")
        }
        return .processed
    }
}

class MazegakiSelectionMode: Mode, ModeWithCandidates {
    let noCandidates: String = "(候補なし)"
    let map = MazegakiSelectionMap.map
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
        NSLog("MazegakiSelectionMode.init")
    }
    func showWindow() {
        candidateWindow.update()
        candidateWindow.show()
    }
    func handle(_ inputEvent: InputEvent, client: (any Client)!, controller: any Controller) -> Bool {
        // キーで選択して確定。右手ホームの4キーの後数字の1～0
        NSLog("MazegakiSelectionMode.handle: \(inputEvent) \(client!) \(controller)")
        if let selectKeys = candidateWindow.selectionKeys() as? [Int] {
            NSLog("  selectKeys = \(selectKeys)")
            if let keyCode = inputEvent.event?.keyCode {
                NSLog("  keyCode = \(Int(keyCode))")
                if let index = selectKeys.firstIndex(of: Int(keyCode)) {
                    NSLog("  index = \(index)")
                    let hit = mazegaki.find(hit)
                    let candidates = hit.candidates()
                    if index < candidates.count {
                        let text = candidates[index]
                        if text != noCandidates {
                            NSLog("  Candate selected \(text) by key \(inputEvent)")
                            client.insertText(text, replacementRange: target)
                            cancel()
                        }
                    }
                    return true
                }
            }
        }
        if let command = map.lookup(input: inputEvent) {
            switch command {
            case .passthrough:
                break
            case .processed:
                return true
            case .action(let action):
                NSLog("execute action \(action)")
                let ret = action.execute(client: client, mode: self, controller: controller)
                switch ret {
                case .passthrough:
                    break
                case .processed:
                    return true
                default:
                    break
                }
            default:
                break
            }
        }
        switch inputEvent.type {
        case .printable, .enter, .left, .right, .up, .down, .space:
            if let event = inputEvent.event {
                NSLog("Forward to candidateWindow: \([event])")
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
    func update() {
        candidateWindow.update()
    }
    func cancel() {
        NSLog("MazegakiSelectionMode.cancel")
        candidateWindow.hide()
        controller.popMode()
    }
    func reset() {
    }
    
    func candidates(_ sender: Any!) -> [Any]! {
        NSLog("MazegakiSelectionMode.candidates")
        let hit = mazegaki.find(hit)
        if hit.found {
            return hit.candidates()
        } else {
            return [noCandidates]
        }
    }
    
    func candidateSelected(_ candidateString: NSAttributedString!, client: (any Client)!) {
        client.insertText(candidateString.string, replacementRange: target)
        cancel()
    }
    
    func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        
    }
}

class MazegakiAction: Action {
    func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        return .passthrough
    }
    func execute(client: any Client, mode mode1: any Mode, controller: any Controller) -> Command {
        if let mode = mode1 as? MazegakiSelectionMode {
            return action(client: client, mode: mode, controller: controller)
        }
        return .passthrough
    }
}

class MazegakiSelectionCancelAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        mode.cancel()
        return .processed
    }
}
/// 次の候補セットに送る(再変換)
class MazegakiSelectionNextAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        let newHit = mode.mazegaki.find(mode.hit) // advance
        if newHit.found {
            mode.hit = newHit
            mode.update()
        }
        return .processed
    }
}
/// 直前の候補を出すことを試みる
/// 送りがなモードならば送りがなを縮める
/// そうでなければ読みをのばす
class MazegakiSelectionPreviousAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if let hit = mode.hit {
            var tryHit = hit.duplicate()
            if hit.length < hit.yomi.count {
                tryHit.length = hit.length + 1
            } else if mode.mazegaki.inflection && hit.offset > 1 {
                tryHit.offset = hit.offset - 1
            } else {
                return .processed
            }
            let newHit = mode.mazegaki.find(mode.mazegaki.find(tryHit))
            if newHit.found &&
                !(newHit.length == hit.length && newHit.offset == hit.offset) {
                mode.hit = newHit
                mode.update()
                return .processed
            }
        }
        return .processed
    }
}
/// 変換を最初からやり直す
class MazegakiSelectionRestartAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        mode.hit = nil
        mode.update()
        return .processed
    }
}
/// 送りがな部分をのばす
class MazegakiSelectionOkuriNobashiAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.hit != nil && mode.hit!.offset < Mazegaki.maxInflection {
            mode.hit!.offset += 1
        }
        mode.update()
        return .processed
    }
}
/// 送りがな部分を縮める
class MazegakiSelectionOkuriChijimeAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.hit != nil && mode.hit!.offset > 1 {
            mode.hit!.offset -= 1
        }
        mode.update()
        return .processed
    }
}

class MazegakiSelectionMap {
    static var map = {
        let map = Keymap("MazegakiSelectionMap")
        map.replace(input: InputEvent(type: .escape, text: "\u{1b}"), entry: .action(MazegakiSelectionCancelAction()))
        map.replace(input: InputEvent(type: .space, text: " "),       entry: .action(MazegakiSelectionNextAction()))
        map.replace(input: InputEvent(type: .down, text: " "),        entry: .action(MazegakiSelectionNextAction()))
        map.replace(input: InputEvent(type: .delete, text: "\u{08}"), entry: .action(MazegakiSelectionPreviousAction()))
        map.replace(input: InputEvent(type: .up, text: "\u{08}"),     entry: .action(MazegakiSelectionPreviousAction()))
        map.replace(input: InputEvent(type: .printable, text: "<"),   entry: .action(MazegakiSelectionOkuriNobashiAction()))
        map.replace(input: InputEvent(type: .printable, text: ">"),   entry: .action(MazegakiSelectionOkuriChijimeAction()))
        map.replace(input: InputEvent(type: .printable, text: "!"),   entry: .action(MazegakiSelectionRestartAction()))
        return map
    }()
}
