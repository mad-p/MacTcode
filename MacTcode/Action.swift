//
//  Action.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

protocol Action {
    func execute(client: Client, mode: Mode, controller: Controller) -> Command
}

/// キーシーケンスのprefixとしてたまっているものを入力する
class EmitPendingAction: Action {
    func execute(client: any Client, mode: Mode, controller: Controller) -> Command {
        if let pending = mode as? MultiStroke {
            let input = pending.pending
            if input.count > 0 {
                let str = input.map { $0.text ?? "" }.joined()
                return .text(str)
            }
        }
        return .text(" ")
    }
}

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

/// 途中までのキーシーケンス、入力モードなどを全部キャンセルする
class ResetAllStateAction: Action {
    func execute(client: any Client, mode: Mode, controller: Controller) -> Command {
        mode.reset()
        return .processed
    }
}
