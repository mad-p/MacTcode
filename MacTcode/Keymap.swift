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
        
        var flags = ""
        if event.modifierFlags.contains(.option) {
            flags.append(" options")
        }
        if event.modifierFlags.contains(.command) {
            flags.append(" command")
        }
        if event.modifierFlags.contains(.function) {
            flags.append(" function")
        }
        if event.modifierFlags.contains(.control) {
            flags.append(" control")
        }
        NSLog(" modifierFlags: \(flags)")
        
        var type: InputEventType = .unknown
        if event.modifierFlags.contains(.option)
            || event.modifierFlags.contains(.command)
        {
            type = .unknown
        } else if printable {
            if text != nil && " ',.-=/;".contains(text!) && event.modifierFlags.contains(.control) {
                type = .control_punct
            } else if text == " " {
                type = .space
            } else {
                type = .printable
            }
        } else {
            switch(text) {
            case " ":      type = .space
            case "\u{08}": type = .delete
            case "\n":     type = .enter
            case "\u{1b}": type = .escape
            default:
                NSLog("Translate by keycode")
                switch(event.keyCode) {
                case 36:  type = .enter
                case 123: type = .left
                case 124: type = .right
                case 125: type = .down
                case 126: type = .up
                case 51:  type = .delete
                default:
                    NSLog("  unknown keycode")
                    type = .unknown
                }
            }
        }
        let event = InputEvent(type: type, text: text, event: event)
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
    init(_ name: String, fromArray chars: [String]) {
        self.name = name
        precondition(chars.count == nKeys, "Keymap \(name) fromChars: must have \(nKeys) characters")
        for i in 0..<nKeys {
            let key = InputEvent(type: .printable, text: Translator.keyToStr(i), event: NSEvent())
            add(key, .text(chars[i]))
        }
    }
    convenience init!(_ name: String, fromChars chars: String) {
        self.init(name, fromArray: chars.map{String($0)})
    }
    init(_ name: String, from2d: String!) {
        self.name = name
        let table = from2d.components(separatedBy: "\n").map { $0.map { String($0) }}
        precondition(table.count == nKeys, "2Dkeymap \(name) from2d: must have \(nKeys) lines")
        // check if we have exactly nKeys in each row
        var ok = true
        for j in 0..<nKeys {
            if table[j].count != nKeys {
                NSLog("2DKeymap \(name) row \(j) must have \(nKeys) chars")
                ok = false
            }
        }
        precondition(ok, "2DKeymap \(name) from2d: had erroneous definition in rows")
        
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
        if map[key] != nil {
            NSLog("Keymap \(name) replace \(key) to new entry \(String(describing: entry))")
        }
        map[key] = entry
    }
    func replace(input: InputEvent, entry: Command?) {
        if let e = entry {
            add(input, e)
        } else {
            NSLog("Keymap \(name) undefine \(input)")
            map.removeValue(forKey: input)
        }
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
    static func replace(keySequence: [InputEvent], keymap: Keymap, entry newEntry: Command) {
        let (_, key, map) = traverse(keySequence: keySequence, keymap: keymap)
        if let entry = map.lookup(input: key) {
            switch entry {
            case .keymap(_):
                break      // リプレースしようと思ったところにはすでにキーマップが入ってた
            default:
                map.replace(input: key, entry: newEntry)
            }
        }
        // 最後に探索した場所に追加する
        map.replace(input: key, entry: newEntry)
    }
    static func define(keys: [Int], keymap: Keymap, entry: Command) {
        let events = keys.map { InputEvent(type: .printable, text: Translator.keyToStr($0)) }
        replace(keySequence: events, keymap: keymap, entry: entry)
    }
    static func define(keys: [Int], keymap: Keymap, action: Action) {
        define(keys: keys, keymap: keymap, entry: Command.action(action))
    }
    static func define(sequence: String, keymap: Keymap, entry: Command) {
        let events = sequence.map { InputEvent(type: .printable, text: String($0)) }
        replace(keySequence: events, keymap: keymap, entry: entry)
    }
    
    static func define(sequence: String, keymap: Keymap, action: Action) {
        define(sequence: sequence, keymap: keymap, entry: Command.action(action))
    }
}
