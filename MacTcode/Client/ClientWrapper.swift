//
//  ClientWrapper.swift
//  MacTcode
//
//  Created by maeda on 2024/08/15.
//

import Cocoa
import InputMethodKit

/// IMKTextInputをMyInputTextに見せかけるラッパー
class ClientWrapper: Client {
    let client: IMKTextInput
    let _bundleId: String!
    init(_ client: IMKTextInput!, _ bundleId: String!) {
        self.client = client
        self._bundleId = bundleId!
    }
    func bundleId() -> String! {
        return _bundleId
    }
    func selectedRange() -> NSRange {
        return client.selectedRange()
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer
    ) -> String! {
        return client.string(from: range, actualRange: actualRange)
    }
    func insertText(
        _ string: String,
        replacementRange rr: NSRange
    ) {
        client.insertText(string, replacementRange: rr)
    }
    func sendBackspace() {
        let keyCode: CGKeyCode = 0x33
        let backspaceDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let backspaceUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        backspaceDown?.post(tap: .cghidEventTap)
        backspaceUp?.post(tap: .cghidEventTap)
    }
}
