//
//  TopLevelMap.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Foundation

class TopLevelMap {
    static var map = {
        let map = Keymap("TopLevelMap")
        map.replace(input: InputEvent(type: .space, text: " "), entry: .action(EmitPendingAction()))
        map.replace(input: InputEvent(type: .escape, text: "\u{1b}"), entry: .action(ResetAllStateAction()))
        map.replace(input: InputEvent(type: .delete, text: "\u{08}"), entry: .action(RemoveLastPendingAction()))
        return map
    }()
}