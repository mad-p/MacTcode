//
//  LineModeMap.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2025/11/24.
//

import Foundation

class LineModeMap {
    static var map = {
        let map = Keymap("LineModeMap")
        map.replace(input: InputEvent(type: .escape, text: "\u{1b}"), entry: .action(LineModeCancelAction()))
        map.replace(input: InputEvent(type: .control_g, text: "\u{07}"), entry: .action(LineModeCancelAction()))
        map.replace(input: InputEvent(type: .enter, text: "\u{0a}"),  entry: .action(LineModeKakuteiAction()))
        map.replace(input: InputEvent(type: .tab, text: "\u{09}"),    entry: .action(LineModeKakuteiAction()))
        map.replace(input: InputEvent(type: .delete, text: "\u{08}"), entry: .action(LineModeBackspaceAction()))
        return map
    }()
}
