//
//  Client.swift
//  MacTcode
//
//  Created by maeda on 2024/06/04.
//

import Cocoa

protocol Client {
    func selectedRange() -> NSRange
    func string(
        from range: NSRange,
        actualRange: NSRangePointer
    ) -> String!
    func insertText(
        _ string: String,
        replacementRange: NSRange
    )
    func sendBackspace()
}
