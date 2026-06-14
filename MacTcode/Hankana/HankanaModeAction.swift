//
//  HankanaModeAction.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2026/06/14.
//

import Foundation

class HankanaModeAction: Action {
    func execute(client: Client, mode: Mode, controller: Controller) -> Command {
        controller.pushMode(HankanaMode())
        controller.setInputMode(.hankana)
        return .processed
    }
}
