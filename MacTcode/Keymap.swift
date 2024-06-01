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
    /// テキストをclientに送る
    case text(String, [Int]?)
    /// アクションを実行
    case action(Action)
}

/// キーマップの抽象クラス
protocol Keymap {
    /// 次の入力に対応するコマンドを返す
    func lookup(input: InputEvent) -> Command
    /// 状態を無入力に戻す
    func reset()
}

class PostLookupMap: Keymap {
    /// Tcodeキー2打鍵に対応してCommandを割り当てる
    var map: [[Int]: Command] = [:]
    var prefix: Keymap
    
    init (prefix: Keymap) {
        self.prefix = prefix
    }
    
    func add (_ keys: [Int], _ command: Command) {
        map[keys] = command
    }
    
    func lookup(input: InputEvent) -> Command {
        let first = prefix.lookup(input: input)
        switch first {
        case .text(_, let array):
            if let keys = array {
                if let command = map[keys] {
                    return command
                }
            }
            return first
        default:
            return first
        }
    }
    func reset() {
        prefix.reset()
    }
}
