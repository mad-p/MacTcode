//
//  Mode.swift
//  MacTcode
//
//  Created by maeda on 2024/06/04.
//

import Cocoa
import InputMethodKit

/// 入力モード
protocol Mode {
    /// 入力イベントを処理する
    func handle(_ inputEvent: InputEvent, client: ContextClient!, controller: Controller) -> Bool
    /// すべての状態を初期状態にする
    func reset()
}
