//
//  Keymap.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

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
}

enum KeymapEntry {
    /// まだコマンドが確定しない
    case next(Keymap)
    /// コマンドのうち、textまたはaction
    case command(Command)
}

/// キーマップの抽象クラス
protocol Keymap {
    /// キーマップの名前を返す
    var name: String { get }
    /// 次の入力に対応するコマンドを返す
    func lookup(input: InputEvent) -> KeymapEntry?
    /// 入力に対応するコマンドを上書きする。入力として受け付けられなければfalseを返す
    func replace(input: InputEvent, entry: KeymapEntry?) -> Bool
}

/// ストロークからコマンドへの対応
final class StrokeKeymap: Keymap {
    var name: String
    var map: [KeymapEntry?]
    
    init!(_ name: String, fromArray chars: [String]) {
        self.name = name
        guard chars.count == Translator.nKeys else {
            NSLog("StrokeKeymap \(name) fromChars: must have \(Translator.nKeys) characters")
            return nil
        }
        map = chars.map { char in
                .command(.text(char))
        }
    }
    convenience init!(_ name: String, fromChars chars: String) {
        self.init(name, fromArray: chars.map{String($0)})
    }

    func lookup(input: InputEvent) -> KeymapEntry? {
        switch input.type {
        case .printable(let key):
            if let i = key {
                if (0..<Translator.nKeys).contains(i) {
                    // NSLog("Keymap \(name) lookup(\(input)) got \(String(describing: map[i]))")
                    return map[i]
                } else {
                    // NSLog("Keymap \(name) lookup(\(input)) out of range")
                    return nil
                }
            }
        default:
            break
        }
        // NSLog("Keymap \(name) lookup(\(input)) not supported")
        return nil
    }
    
    func replace(input: InputEvent, entry: KeymapEntry?) -> Bool {
        switch input.type {
        case .printable(let keyNum):
            if let k = keyNum {
                map[k] = entry
                NSLog("Keymap \(name) replace(\(input)) set new entry \(String(describing: entry))")
                return true
            }
        default:
            break
        }
        NSLog("Keymap \(name) replace(\(input)) not supported")
        return false
    }
    
    init?(_ name: String, from2d: String!) {
        self.name = name
        map = []
        let table = from2d.components(separatedBy: "\n").map { $0.map { String($0) }}
        guard table.count == Translator.nKeys else {
            NSLog("StrokeKeymap \(name) from2d: must have \(Translator.nKeys) lines")
            return nil
        }
        
        var failed: Bool = false
        // i: first stroke
        for i in 0..<Translator.nKeys {
            let column = (0..<Translator.nKeys).map { j in // j: second stroke
                table[j][i]
            }
            if let columnmap = StrokeKeymap("\(name)_column\(i)", fromArray: column) {
                map.append(KeymapEntry.next(columnmap))
            } else {
                failed = true
            }
        }
        
        if failed {
            NSLog("StrokeKeymap \(name) from2d: had erroneous definition")
            return nil
        }
    }
}

/// 文字からコマンドへの対応
class SparseMap: Keymap {
    var name: String
    var map: [String: KeymapEntry] = [:]
    init(_ name: String) {
        self.name = name
    }
    func lookup(input: InputEvent) -> KeymapEntry? {
        if let str = input.text {
            // NSLog("Keymap \(name) lookup(\(input)) got \(String(describing: map[str]))")
            return map[str]
        }
        // NSLog("Keymap \(name) lookup(\(input)) not supported")
        return nil
    }
    func add(_ str: String, _ entry: KeymapEntry) {
        NSLog("Keymap \(name) add(\(str)) set new entry \(String(describing: entry))")
        map[str] = entry
    }
    func replace(input: InputEvent, entry: KeymapEntry?) -> Bool {
        if let str = input.text {
            if let e = entry {
                add(str, e)
            } else {
                NSLog("Keymap \(name) replace(\(str)) cleared entry")
                map.removeValue(forKey: str)
            }
            return true
        } else {
            NSLog("Keymap \(name) replace(\(input)) not supported")
            return false
        }
    }
}

class UnionMap: Keymap {
    var name: String
    var keymaps: [Keymap]
    init(_ name: String, keymaps: [Keymap]) {
        self.name = name
        self.keymaps = keymaps
    }
    func lookup(input: InputEvent) -> KeymapEntry? {
        var found: KeymapEntry? = nil
        _ = keymaps.first(where: { map in
            if let entry = map.lookup(input: input) {
                found = entry
                return true
            } else {
                return false
            }
        })
        // NSLog("Keymap \(name) lookup(\(input)) got \(String(describing: found))")
        return found
    }
    func replace(input: InputEvent, entry: KeymapEntry?) -> Bool {
        var done = false
        // もしすでにエントリが存在すれば上書きする
        _ = keymaps.first(where: { map in
            if (map.lookup(input: input)) != nil {
                done = map.replace(input: input, entry: entry)
                if done {
                    NSLog("Keymap \(name) replace(\(input)) replaced in submap \(map.name)")
                }
                return done
            } else {
                return false
            }
        })
        // 存在しなければそのinputで定義できる最初のマップに定義する
        if !done {
            _ = keymaps.first(where: { map in
                done = map.replace(input: input, entry: entry)
                if (done) {
                    NSLog("Keymap \(name) replace(\(input)) replaced in submap \(map.name)")
                }
                return done
            })
        }
        if !done {
            NSLog("Keymap \(name) replace(\(input)) not supported")
        }
        return done
    }
    
    static func wrap(_ keymap: Keymap?) -> Keymap {
        if let keymap = keymap {
            let sparse = SparseMap(keymap.name + "_sparse")
            let union = UnionMap(keymap.name + "_wrapper", keymaps: [sparse, keymap])
            return union
        }
        NSLog("Given keymap is nil")
        return SparseMap("nullmap")
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
                case .next(let keymap):
                    // NSLog("traverse:  got next: keymap \(keymap.name)")
                    lastmap = map
                    map = keymap
                    // continue
                case .command(_):
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
            case .next(_):
                return .pending   // 定義済みシーケンスのprefix部分
            case .command(let command):
                return command    // 見つかった。シーケンスの途中でも見つかったらそれを返す
            }
        } else {
            return .passthrough   // このキーマップにそのシーケンスはない
        }
    }
    static func replace(keySequence: [InputEvent], keymap: Keymap, entry newEntry: KeymapEntry) -> Bool {
        let (_, key, map) = traverse(keySequence: keySequence, keymap: keymap)
        if let entry = map.lookup(input: key) {
            switch entry {
            case .next(_):
                break      // リプレースしようと思ったところにはすでにキーマップが入ってた
            case .command(_):
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
    static func define(keys: [Int], keymap: Keymap, entry: KeymapEntry) -> Bool {
        let events = keys.map { InputEvent(type: .printable($0), text: Translator.keyToStr($0)) }
        return replace(keySequence: events, keymap: keymap, entry: entry)
    }
    static func define(keys: [Int], keymap: Keymap, command: Command) -> Bool {
        let entry = KeymapEntry.command(command)
        return define(keys: keys, keymap: keymap, entry: entry)
    }
    static func define(keys: [Int], keymap: Keymap, action: Action) -> Bool {
        return define(keys: keys, keymap: keymap, command: Command.action(action))
    }
    static func define(sequence: String, keymap: Keymap, entry: KeymapEntry) -> Bool {
        let events = sequence.map { InputEvent(type: .printable(Translator.strToKey(String($0))), text: String($0)) }
        return replace(keySequence: events, keymap: keymap, entry: entry)
    }
    static func define(sequence: String, keymap: Keymap, command: Command) -> Bool {
        let entry = KeymapEntry.command(command)
        return define(sequence: sequence, keymap: keymap, entry: entry)
    }
    static func define(sequence: String, keymap: Keymap, action: Action) -> Bool {
        return define(sequence: sequence, keymap: keymap, command: Command.action(action))
    }
}
