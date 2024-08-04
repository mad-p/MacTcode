//
//  EmitPendingAction.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

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
