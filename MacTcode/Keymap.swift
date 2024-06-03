//
//  Keymap.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

let nKeys = 40

/// 入力イベントに対して、キーマップで対応するコマンド
enum Command {
    /// イベントを処理せず、そのままclientに送る
    case passthrough
    /// イベントは処理されたが、状態変化だけで何も生成しなかった
    case processed
    /// カスケードmap、2打鍵mapの途中
    case pending
    /// テキストをclientに送る
    case text(String)
    /// アクションを実行
    case action(Action)
    /// キーマップ
    case keymap(Keymap)
}

/// NSEventをInputEventに変換する
class Translator {
    static var layout: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "'", ",", ".", "p", "y", "f", "g", "c", "r", "l",
        "a", "o", "e", "u", "i", "d", "h", "t", "n", "s",
        ";", "q", "j", "k", "x", "b", "m", "w", "v", "z",
    ]
    static func strToKey(_ string: String!) -> Int? {
        return layout.firstIndex(of: string)
    }
    static func keyToStr(_ key: Int) -> String? {
        if (0..<nKeys).contains(key) {
            return layout[key]
        } else {
            return nil
        }
    }
    static func translate(event: NSEvent!) -> InputEvent {
        NSLog("event.keyCode = \(event.keyCode); event.characters = \(event.characters ?? "nil"); event.modifierFlags = \(event.modifierFlags)")
        
        let text = event.characters
        let printable = if text != nil {
            text!.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation })
        } else {
            false
        }
        
        let type: InputEventType =
        if event.modifierFlags.contains(.option)
            || event.modifierFlags.contains(.command)
            || event.modifierFlags.contains(.function)
        {
            .unknown
        } else if printable {
            if text == " " {
                .space
            } else {
                .printable
            }
        } else {
            switch(text) {
            case " ": .space
            case "\u{08}": .delete
            case "\n": .enter
            case "\u{1b}": .escape
            default:
                switch(event.keyCode) {
                case 38: .enter
                case 123: .left
                case 124: .right
                case 125: .down
                case 126: .up
                case 51: .delete
                default: .unknown
                }
            }
        }
        let event = InputEvent(type: type, text: text)
        NSLog("  translated to \(event)")
        return event
    }
}

/// イベントからコマンドへの対応
class Keymap {
    var name: String
    var map: [InputEvent: Command] = [:]
    init(_ name: String) {
        self.name = name
    }
    init!(_ name: String, fromArray chars: [String]) {
        self.name = name
        guard chars.count == nKeys else {
            NSLog("Keymap \(name) fromChars: must have \(nKeys) characters")
            return nil
        }
        for i in 0..<nKeys {
            let key = InputEvent(type: .printable, text: Translator.keyToStr(i))
            add(key, .text(chars[i]))
        }
    }
    convenience init!(_ name: String, fromChars chars: String) {
        self.init(name, fromArray: chars.map{String($0)})
    }
    init!(_ name: String, from2d: String!) {
        self.name = name
        let table = from2d.components(separatedBy: "\n").map { $0.map { String($0) }}
        guard table.count == nKeys else {
            NSLog("2Dkeymap \(name) from2d: must have \(nKeys) lines")
            return nil
        }
        
        // check if we have exactly nKeys in each row
        var failed = false
        for j in 0..<nKeys {
            if table[j].count != nKeys {
                NSLog("2DKeymap \(name) row \(j) must have \(nKeys) chars")
                failed = true
            }
        }
        if failed {
            NSLog("2DKeymap \(name) from2d: had erroneous definition")
            return nil
        }
        
        // i: first stroke (column in table)
        for i in 0..<nKeys {
            let columnKey = InputEvent(type: .printable, text: Translator.keyToStr(i))
            let columnMap = Keymap("\(name)_column\(i)")
            add(columnKey, .keymap(columnMap))
            // j: second stroke (row in table)
            for j in 0..<nKeys {
                let rowKey = InputEvent(type: .printable, text: Translator.keyToStr(j))
                columnMap.add(rowKey, .text(table[j][i]))
            }
        }
    }
    func lookup(input: InputEvent) -> Command? {
        return map[input]
    }
    func add(_ key: InputEvent, _ entry: Command) {
        NSLog("Keymap \(name) add(\(key) set new entry \(String(describing: entry))")
        map[key] = entry
    }
    func replace(input: InputEvent, entry: Command?) -> Bool {
        if let e = entry {
            add(input, e)
        } else {
            NSLog("Keymap \(name) replace(\(input)) cleared entry")
            map.removeValue(forKey: input)
        }
        return true
    }
}

class KeymapResolver {
    /// keySequenceでキーマップを探索し、最初に未定義またはコマンドを見つけたエントリの場所
    /// @returns (i, key, map):
    ///    - i: keySequence内のキーの位置
    ///    - key: 見つけたエントリに対応するキー
    ///    - map: mapをkeyで引くとエントリが得られる
    static func traverse(keySequence: [InputEvent], keymap: Keymap) -> (Int, InputEvent, Keymap) {
        var map = keymap
        var lastmap = keymap
        for i in 0..<keySequence.count {
            // NSLog("traverse: i=\(i) input: \(keySequence[i]) in keymap: \(map.name)")
            if let next = map.lookup(input: keySequence[i]) {
                switch next {
                case .keymap(let keymap):
                    // NSLog("traverse:  got next: keymap \(keymap.name)")
                    lastmap = map
                    map = keymap
                    // continue
                default:
                    // keySequence[i]で最初にコマンドが得られた
                    // NSLog("traverse found first command: seq: \(keySequence) -> depth \(i) last key \(keySequence[i]) in map \(map.name)")
                    return (i, keySequence[i], map)
                }
            } else {
                // NSLog("traverse found first undefined: seq: \(keySequence) -> depth \(i) last key \(keySequence[i]) in map \(map.name)")
                // 途中で未定義キーに出会った
                return (i, keySequence[i], map)
            }
        }
        // 最後まで行ったがまだキーマップ
        let i = keySequence.count - 1
        // NSLog("traverse reached lastmap \(lastmap.name) i=\(i) event=\(keySequence[i])")
        return (i, keySequence[i], lastmap)
    }
    /// keySequenceでkeymapを探索し、最初に見つかったcommandを返す
    /// @returns: command
    ///    - .pending: 定義済みシーケンスのprefix部分。次の入力がないと定まらない
    ///    - .passthrough: このマップにそのシーケンスは定義されていない
    ///    - .text: テキスト。
    ///    - .action: アクション
    static func resolve(keySequence: [InputEvent], keymap: Keymap) -> Command {
        let (_, key, map) = traverse(keySequence: keySequence, keymap: keymap)
        if let entry = map.lookup(input: key) {
            switch entry {
            case .keymap(_):
                return .pending   // 定義済みシーケンスのprefix部分
            default:
                return entry    // 見つかった。シーケンスの途中でも見つかったらそれを返す
            }
        } else {
            return .passthrough   // このキーマップにそのシーケンスはない
        }
    }
    static func replace(keySequence: [InputEvent], keymap: Keymap, entry newEntry: Command) -> Bool {
        let (_, key, map) = traverse(keySequence: keySequence, keymap: keymap)
        if let entry = map.lookup(input: key) {
            switch entry {
            case .keymap(_):
                break      // リプレースしようと思ったところにはすでにキーマップが入ってた
            default:
                if map.replace(input: key, entry: newEntry) {
                    return true    // 見つかった。リプレースした
                }
            }
        }
        // 最後に探索した場所に追加できればする
        if map.replace(input: key, entry: newEntry) {
            return true
        }
        // 追加できなかった。自動で中間マップを作ったりはしない
        return false
    }
    static func define(keys: [Int], keymap: Keymap, entry: Command) -> Bool {
        let events = keys.map { InputEvent(type: .printable, text: Translator.keyToStr($0)) }
        return replace(keySequence: events, keymap: keymap, entry: entry)
    }
    static func define(keys: [Int], keymap: Keymap, action: Action) -> Bool {
        return define(keys: keys, keymap: keymap, entry: Command.action(action))
    }
    static func define(sequence: String, keymap: Keymap, entry: Command) -> Bool {
        let events = sequence.map { InputEvent(type: .printable, text: String($0)) }
        return replace(keySequence: events, keymap: keymap, entry: entry)
    }
    
    static func define(sequence: String, keymap: Keymap, action: Action) -> Bool {
        return define(sequence: sequence, keymap: keymap, entry: Command.action(action))
    }
}
