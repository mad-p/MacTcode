//
//  Action.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

/// キーマップに登録するアクションの抽象クラス
protocol Action {
    func execute(client: Client, mode: Mode, controller: Controller) -> Command
}
