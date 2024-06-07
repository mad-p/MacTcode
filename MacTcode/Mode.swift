//
//  Mode.swift
//  MacTcode
//
//  Created by maeda on 2024/06/04.
//

import Cocoa
import InputMethodKit

protocol Mode {
    /// 入力イベントを処理する
    func handle(_ inputEvent: InputEvent, client: Client!, modeHolder: ModeHolder) -> Bool
    /// すべての状態を初期状態にする
    func reset()
    /// 変換候補を返す
    func candidates(_ sender: Any!) -> [Any]!
    /// 候補選択された
    func candidateSelected(_ candidateString: NSAttributedString!, client: Client!, modeHolder: ModeHolder)
    /// 別の候補が選択された
    func candidateSelectionChanged(_ candidateString: NSAttributedString!, client: Client!, modeHolder: ModeHolder)
}

protocol MultiStroke {
    /// 複数キーコマンドの入力途中のイベント
    var pending: [InputEvent] { get }
    /// pending中のイベントをクリアする
    func resetPending()
    func removeLastPending()
}

enum WindowType {
    case column
    case row
}

protocol ModeHolder {
    var mode: Mode { get }
    func setMode(_ mode: Mode)
    var window: IMKCandidates? { get }
    func createWindow(_ type: WindowType) -> IMKCandidates
}
