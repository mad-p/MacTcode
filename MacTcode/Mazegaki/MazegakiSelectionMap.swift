//
//  MazegakiSelectionMap.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

import Foundation

class MazegakiSelectionMap {
    static var map = {
        let map = Keymap("MazegakiSelectionMap")
        map.replace(input: InputEvent(type: .escape, text: "\u{1b}"), entry: .action(MazegakiSelectionCancelAction()))
        map.replace(input: InputEvent(type: .control_g, text: "\u{07}"), entry: .action(MazegakiSelectionCancelAction()))
        map.replace(input: InputEvent(type: .enter, text: "\u{0a}"),  entry: .action(MazegakiSelectionKakuteiAction()))
        map.replace(input: InputEvent(type: .tab, text: "\u{09}"),    entry: .action(MazegakiSelectionKakuteiAction()))
        map.replace(input: InputEvent(type: .space, text: " "),       entry: .action(MazegakiSelectionNextAction()))
        map.replace(input: InputEvent(type: .down, text: " "),        entry: .action(MazegakiSelectionNextAction()))
        map.replace(input: InputEvent(type: .delete, text: "\u{08}"), entry: .action(MazegakiSelectionPreviousAction()))
        map.replace(input: InputEvent(type: .up, text: "\u{08}"),     entry: .action(MazegakiSelectionPreviousAction()))
        map.replace(input: InputEvent(type: .printable, text: "<"),   entry: .action(MazegakiSelectionOkuriNobashiAction()))
        map.replace(input: InputEvent(type: .printable, text: ">"),   entry: .action(MazegakiSelectionOkuriChijimeAction()))
        map.replace(input: InputEvent(type: .printable, text: "/"),   entry: .action(MazegakiSelectionRestartAction()))
        return map
    }()
}
