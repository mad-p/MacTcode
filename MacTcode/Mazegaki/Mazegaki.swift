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
    let context: YomiContext
    
    init(_ context: YomiContext, inflection: Bool) {
        self.context = context
        let text = context.string
        self.fixed = context.fromSelection
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
    func submit(hit: MazegakiHit, index: Int, client: Client) -> Bool {
        if !hit.found || index >= hit.candidates().count {
            return false
        }
        return self.submit(hit: hit, string: hit.candidates()[index], client: client)
    }
    
    func submit(hit: MazegakiHit, string: String, client: Client) -> Bool {
        guard let client = client as? ContextClient else {
            Log.i("★★Can't happen: Mazegaki.submit: client is not ContextClient")
            return false
        }
        if !hit.found {
            return false
        }
        let length = hit.length
        Log.i("Kakutei \(string)  client=\(type(of:client))")
        client.replaceYomi(string, length: length, from: context)
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
        // postfix bushu
        guard let client = client as? ContextClient else {
            Log.i("★★Can't happen: PostfixBushuAction: client is not ContextClient")
            return .processed
        }
        let context = client.getYomi(1, 10)
        if context.string.count < 1 {
            Log.i("Mazegaki henkan: no input")
            return .processed
        }
        let text = context.string
        let mazegaki = Mazegaki(context, inflection: inflection)
        if context.fromSelection {
            Log.i("Mazegaki: Offline from selection \(text)")
        } else {
            Log.i("Mazegaki: from \(text)")
        }
        
        let hits = mazegaki.find()
        if hits.isEmpty {
            return .processed
        }
        if !inflection && hits.count == 1 && hits[0].candidates().count == 1 {
            if mazegaki.submit(hit: hits[0], index: 0, client: client) {
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
    var candidateString: String = ""
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
    func handle(_ inputEvent: InputEvent, client: ContextClient!, controller: any Controller) -> Bool {
        // キーで選択して確定。右手ホームの4キーの後数字の1～0
        Log.i("MazegakiSelectionMode.handle: event=\(inputEvent) client=\(client!) controller=\(controller)")
        if let selectKeys = candidateWindow.selectionKeys() as? [Int] {
            Log.i("  selectKeys = \(selectKeys)")
            if let keyCode = inputEvent.event?.keyCode {
                Log.i("  keyCode = \(Int(keyCode))")
                if let index = selectKeys.firstIndex(of: Int(keyCode)) {
                    Log.i("  index = \(index)")
                    let candidates = hits[row].candidates()
                    if index < candidates.count {
                        if mazegaki.submit(hit: hits[row], index: index, client: client) {
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
                break
            case .action(let action):
                Log.i("execute action \(action)")
                _ = action.execute(client: client, mode: self, controller: controller)
                break
            default:
                break
            }
            return true
        }
        switch inputEvent.type {
        case .printable, .enter, .left, .right, .up, .down, .space, .tab:
            if let event = inputEvent.event {
                Log.i("Forward to candidateWindow: \([event])")
                candidateWindow.interpretKeyEvents([event])
            }
            return true
        case .delete, .escape, .control_g:
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
        Log.i("candidateSelected \(candidateString.string)")
        _ = mazegaki.submit(hit: hits[row], string: candidateString.string, client: client)
        cancel()
    }
    
    func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        self.candidateString = candidateString.string
        Log.i("candidateSelectionChanged \(candidateString.string)")
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
        Log.i("CancelAction")
        mode.cancel()
        return .processed
    }
}

class MazegakiSelectionKakuteiAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        Log.i("KakuteiAction")
        _ = mode.mazegaki.submit(hit: mode.hits[mode.row], string: mode.candidateString, client: client)
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
        Log.i("RestartAction")
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
                if let newRow = ((mode.row+1)..<mode.hits.count).first(where: { r in
                    mode.hits[r].offset != offset
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
                if let index = (1...mode.row).first(where: { r in
                    (0..<mode.hits.count).contains(mode.row - r) &&
                    mode.hits[mode.row - r].offset != offset
                }) {
                    mode.row = mode.row - index
                    mode.update()
                } else {
                    mode.row = 0
                    mode.update()
                }
            } else {
                mode.row = 0
                mode.update()
            }
        }
        return .processed
    }
}

class MazegakiSelectionMap {
    static var map = {
        let map = Keymap("MazegakiSelectionMap")
        map.replace(input: InputEvent(type: .escape, text: "\u{1b}"), entry: .action(MazegakiSelectionCancelAction()))
        map.replace(input: InputEvent(type: .control_g, text: "\u{07}"), entry: .action(MazegakiSelectionCancelAction()))
        map.replace(input: InputEvent(type: .enter, text: "\u{0a}"),  entry: .action(MazegakiSelectionKakuteiAction()))
        map.replace(input: InputEvent(type: .tab, text: "\u{09}"),    entry: .action(MazegakiSelectionKakuteiAction()))
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
