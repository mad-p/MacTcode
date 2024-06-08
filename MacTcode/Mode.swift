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
    func handle(_ inputEvent: InputEvent, client: Client!, controller: Controller) -> Bool
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

protocol Controller {
    var mode: Mode { get }
    func pushMode(_ mode: Mode)
    func popMode()
    var candidateWindow: IMKCandidates { get }
}

protocol ModeWithCandidates {
    /// 変換候補Windowを表示する
    func showWindow()
    /// 変換候補を返す
    func candidates(_ sender: Any!) -> [Any]!
    /// 候補選択された
    func candidateSelected(_ candidateString: NSAttributedString!, client: Client!)
    /// 別の候補が選択された
    func candidateSelectionChanged(_ candidateString: NSAttributedString!)
}
