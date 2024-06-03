//
//  Action.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

protocol Client {
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
    func execute(client: Client, input: [InputEvent]) -> Command
}

class PendingEmitterAction: Action {
    func execute(client: any Client, input: [InputEvent]) -> Command {
        let range: Range<Int> = if input.count == 1 {
            0..<1 // only the last
        } else {
            0..<input.count - 1 // all but last
        }
        if input.count >= 1 {
            let str = range.map { i in
                input[i].text ?? ""
            }.joined()
            return .text(str)
        }
        return .processed
    }
}

class ResetAllStateAction: Action {
    func execute(client: any Client, input: [InputEvent]) -> Command {
        return .processed
    }
    static func isResetAction(entry: Command) -> Bool {
        switch entry {
        case .action(let action):
            return action is ResetAllStateAction
        default:
            return false
        }
    }
}
