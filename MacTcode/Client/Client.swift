//
//  Client.swift
//  MacTcode
//
//  Created by maeda on 2024/06/04.
//

import Cocoa

/// IMKTextInputのラッパー
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
    func setMarkedText(
        _ string: String,
        selectionRange: NSRange,
        replacementRange: NSRange
    )
    func sendBackspace()
    func bundleId() -> String!
}
