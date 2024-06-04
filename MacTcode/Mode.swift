//
//  Mode.swift
//  MacTcode
//
//  Created by maeda on 2024/06/04.
//

import Cocoa

protocol Mode {
    /// 入力イベントを処理する
    func handle(_ inputEvent: InputEvent, client: Client!, modeHolder: ModeHolder) -> Bool
    /// すべての状態を初期状態にする
    func reset()
}

protocol MultiStroke {
    /// 複数キーコマンドの入力途中のイベント
    var pending: [InputEvent] { get }
    /// pending中のイベントをクリアする
    func resetPending()
    func removeLastPending()
}

protocol ModeHolder {
    var mode: Mode { get }
    func setMode(_ mode: Mode)
}
