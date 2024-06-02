//
//  Action.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

protocol MyInputText {
    func selectedRange() -> NSRange
    func string(
        from range: NSRange,
        actualRange: NSRangePointer!
    ) -> String!
    func insertText(
        _ string: String!,
        replacementRange: NSRange
    )
    func sendBackspace()
}

protocol Action {
    func execute(client: MyInputText, input: [InputEvent]) -> Command
}
