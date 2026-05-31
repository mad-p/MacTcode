//
//  ZenkakuModeAction.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

class ZenkakuModeAction: Action {
    func execute(client: Client, mode: Mode, controller: Controller) -> Command {
        controller.pushMode(ZenkakuMode(controller: controller, setting: .multi))
        return .processed
    }
}
class ZenkakuOneModeAction: Action {
    func execute(client: Client, mode: Mode, controller: Controller) -> Command {
        controller.pushMode(ZenkakuMode(controller: controller, setting: .single))
        return .processed
    }
}
