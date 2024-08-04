//
//  ResetAllStateAction.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

/// 途中までのキーシーケンス、入力モードなどを全部キャンセルする
class ResetAllStateAction: Action {
    func execute(client: any Client, mode: Mode, controller: Controller) -> Command {
        mode.reset()
        return .processed
    }
}
