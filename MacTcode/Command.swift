//
//  Command.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

/// 入力イベントの処理を表す
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
