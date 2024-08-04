//
//  KeymapResolver.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

/// 入力イベントの列からKeymapをたどる
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
            // Log.i("traverse: i=\(i) input: \(keySequence[i]) in keymap: \(map.name)")
            if let next = map.lookup(input: keySequence[i]) {
                switch next {
                case .keymap(let keymap):
                    // Log.i("traverse:  got next: keymap \(keymap.name)")
                    lastmap = map
                    map = keymap
                    // continue
                default:
                    // keySequence[i]で最初にコマンドが得られた
                    // Log.i("traverse found first command: seq: \(keySequence) -> depth \(i) last key \(keySequence[i]) in map \(map.name)")
                    return (i, keySequence[i], map)
                }
            } else {
                // Log.i("traverse found first undefined: seq: \(keySequence) -> depth \(i) last key \(keySequence[i]) in map \(map.name)")
                // 途中で未定義キーに出会った
                return (i, keySequence[i], map)
            }
        }
        // 最後まで行ったがまだキーマップ
        let i = keySequence.count - 1
        // Log.i("traverse reached lastmap \(lastmap.name) i=\(i) event=\(keySequence[i])")
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
