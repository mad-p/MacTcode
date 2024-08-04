//
//  RemoveLastPendingAction.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

/// キーシーケンスの途中だったら最後のものを消す
/// シーケンスでなければ、入力イベントをそのままクライアントに渡す
class RemoveLastPendingAction: Action {
    func execute(client: any Client, mode: Mode, controller: Controller) -> Command {
        if let pending = mode as? MultiStroke {
            if pending.pending.count > 0 {
                // pendingキーがあればひとつずつ消す
                pending.removeLastPending()
                return .processed
            }
        }
        // なければそのままクライアントに送る
        return .passthrough
    }
}
