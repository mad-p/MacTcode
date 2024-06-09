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
        Log.i("Read mazegaki dictionary...")
        dict = [:]
        if let mazedic = Config.loadConfig(file: "mazegaki.dic") {
            for line in mazedic.components(separatedBy: .newlines) {
                let kv = line.components(separatedBy: " ")
                if kv.count == 2 {
                    dict[kv[0]] = kv[1]
                } else {
                    if line.count > 0 {
                        Log.i("Invalid mazegaki.dic line: \(line)")
                    }
                }
            }
        }
        Log.i("\(dict.count) mazegaki entries read")
    }
    
    private init() {
        readDictionary()
    }
}

/// 特定の読み、活用部分に対応する候補全体を表わす
class MazegakiHit: Comparable {
    var yomi: [String] = []
    var found: Bool = false // 見つかったかどうか
    var key: String = ""    // dictを見るときのキー
    var length: Int = 0     // 読みの長さ
    var offset: Int = 0     // 活用部分の長さ
    var cache: [String]? = nil

    func candidates() -> [String] {
        if let ret = cache {
            return ret
        }
        if found {
            if let dictEntry = MazegakiDict.i.dict[key] {
                let inflection = yomi.suffix(offset).joined()
                var cand = dictEntry.components(separatedBy: "/")
                if !cand.isEmpty {
                    cand = cand.filter({ $0 != ""})
                    cand = cand.map { $0 + inflection }
                    cache = cand
                    return cand
                }
            }
        }
        cache = []
        return []
    }
    func duplicate() -> MazegakiHit {
        let newHit = MazegakiHit()
        newHit.yomi = yomi
        newHit.found = found
        newHit.key = key
        newHit.length = length
        newHit.offset = offset
        return newHit
    }
    static func < (lhs: MazegakiHit, rhs: MazegakiHit) -> Bool {
        return lhs.offset < rhs.offset ||
        lhs.length > rhs.length
    }
    
    static func == (lhs: MazegakiHit, rhs: MazegakiHit) -> Bool {
        return lhs.found == rhs.found &&
        lhs.yomi == rhs.yomi &&
        lhs.key == rhs.key &&
        lhs.length == rhs.length &&
        lhs.offset == rhs.offset
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
            // Log.i("Mazegaki.key: yomi=\(yomi.joined())  i=\(i)  offset=\(offset) ->  result=\(res)")
            return res
        } else {
            return nil
        }
    }
    
    /// 全候補の可能性をすべて数えあげる
    func find() -> [MazegakiHit] {
        // 活用しないとき
        // - 最大長さを見つける
        // 活用するとき
        // - 全体の長さが同じときに、活用部分の長さが短い順で全部見つける
        var result: [MazegakiHit] = []
        let iRange = fixed ? [max] : (0..<max).map{ max - $0 }
        for i in iRange {
            let jRange = inflection ? (1..<i).map{$0} : [0]
            for j in jRange {
                if let k = key(i, offset: j) {
                    if MazegakiDict.i.dict[k] != nil {
                        let hit = MazegakiHit()
                        hit.yomi = yomi.suffix(i)
                        hit.key = k
                        hit.length = i
                        hit.found = true
                        hit.offset = j
                        result.append(hit)
                    }
                }
            }
        }
        return result.sorted()
    }
    
    /// 確定するコンビニメソッド
    static func submit(hit: MazegakiHit, index: Int, client: Client) -> Bool {
        if !hit.found || index >= hit.candidates().count {
            return false
        }
        return Mazegaki.submit(hit: hit, string: hit.candidates()[index], client: client)
    }
    
    static func submit(hit: MazegakiHit, string: String, client: Client) -> Bool {
        if !hit.found {
            return false
        }
        let inputLength = hit.length
        let cursor = client.selectedRange()
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
        Log.i("Kakutei \(string)")
        client.insertText(string, replacementRange: target)
        return true
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
                Log.i("Online mazegaki from \(text)")
                mazegaki = Mazegaki(text, inflection: inflection, fixed: false)
            } else {
                Log.i("No yomi")
                return .processed
            }
        } else {
            // mazegaki henkan from selection
            if let text = client.string(from: cursor, actualRange: &replaceRange) {
                Log.i("Offline mazegaki \(text)")
                mazegaki = Mazegaki(text, inflection: inflection, fixed: true)
            } else {
                return .processed
            }
        }
        
        let hits = mazegaki.find()
        if hits.isEmpty {
            return .processed
        }
        if !inflection && hits.count == 1 && hits[0].candidates().count == 1 {
            if Mazegaki.submit(hit: hits[0], index: 0, client: client) {
                return .processed
            }
        }
        let newMode = MazegakiSelectionMode(controller: controller, mazegaki: mazegaki, hits: hits)
        controller.pushMode(newMode)
        newMode.showWindow()
        // Log.i("Mazegaki: more than one candidates")
        
        return .processed
    }
}

class MazegakiSelectionMode: Mode, ModeWithCandidates {
    let map = MazegakiSelectionMap.map
    let mazegaki: Mazegaki
    let hits: [MazegakiHit]
    let controller: Controller
    let candidateWindow: IMKCandidates
    var row: Int
    init(controller: Controller, mazegaki: Mazegaki!, hits: [MazegakiHit]) {
        self.controller = controller
        self.mazegaki = mazegaki
        self.candidateWindow = controller.candidateWindow
        self.hits = hits
        self.row = 0
        Log.i("MazegakiSelectionMode.init")
    }
    func showWindow() {
        candidateWindow.update()
        candidateWindow.show()
    }
    func handle(_ inputEvent: InputEvent, client: (any Client)!, controller: any Controller) -> Bool {
        // キーで選択して確定。右手ホームの4キーの後数字の1～0
        Log.i("MazegakiSelectionMode.handle: \(inputEvent) \(client!) \(controller)")
        if let selectKeys = candidateWindow.selectionKeys() as? [Int] {
            Log.i("  selectKeys = \(selectKeys)")
            if let keyCode = inputEvent.event?.keyCode {
                Log.i("  keyCode = \(Int(keyCode))")
                if let index = selectKeys.firstIndex(of: Int(keyCode)) {
                    Log.i("  index = \(index)")
                    let candidates = hits[row].candidates()
                    if index < candidates.count {
                        if Mazegaki.submit(hit: hits[row], index: index, client: client) {
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
                Log.i("execute action \(action)")
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
                Log.i("Forward to candidateWindow: \([event])")
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
        Log.i("MazegakiSelectionMode.cancel")
        candidateWindow.hide()
        controller.popMode()
    }
    func reset() {
    }
    
    func candidates(_ sender: Any!) -> [Any]! {
        Log.i("MazegakiSelectionMode.candidates")
        return hits[row].candidates()
    }
    
    func candidateSelected(_ candidateString: NSAttributedString!, client: (any Client)!) {
        if Mazegaki.submit(hit: hits[row], string: candidateString.string, client: client) {
            cancel()
        }
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
/// 次の候補セットに送る(いわゆる再変換)
class MazegakiSelectionNextAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.row < mode.hits.count - 1 {
            mode.row += 1
            mode.update()
        }
        return .processed
    }
}
/// 直前の候補に戻る
class MazegakiSelectionPreviousAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.row > 0 {
            mode.row -= 1
            mode.update()
        }
        return .processed
    }
}
/// 変換を最初からやり直す
class MazegakiSelectionRestartAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        mode.row = 0
        mode.update()
        return .processed
    }
}
/// 送りがな部分をのばす
class MazegakiSelectionOkuriNobashiAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.mazegaki.inflection {
            let offset = mode.hits[mode.row].offset
            if offset < Mazegaki.maxInflection {
                let newOffset = offset + 1
                if let newRow = ((mode.row+1)..<mode.hits.count).first(where: { r in
                    mode.hits[r].offset == newOffset
                }) {
                    mode.row = newRow
                    mode.update()
                }
            }
        }
        return .processed
    }
}
/// 送りがな部分を縮める
class MazegakiSelectionOkuriChijimeAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.mazegaki.inflection {
            let offset = mode.hits[mode.row].offset
            if offset > 1 {
                let newOffset = offset - 1
                if let newRow = ((mode.row+1)..<mode.hits.count).first(where: { r in
                    mode.hits[r].offset == newOffset
                }) {
                    mode.row = newRow
                    mode.update()
                }
            }
        }
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
        map.replace(input: InputEvent(type: .printable, text: "/"),   entry: .action(MazegakiSelectionRestartAction()))
        return map
    }()
}
