//
//  MultiStroke.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

/// マルチストロークのキーマップを持つモード
protocol MultiStroke {
    /// 複数キーコマンドの入力途中のイベント
    var pending: [InputEvent] { get }
    /// pending中のイベントをクリアする
    func resetPending()
    func removeLastPending()
}
