//
//  ClientWrapper.swift
//  MacTcode
//
//  Created by maeda on 2024/08/15.
//

import Cocoa
import InputMethodKit

/// IMKTextInputをContextClientに見せかけるラッパー
class ClientWrapper: ContextClient {
    private let inputText: IMKTextInput
    private let _bundleId: String!
    init(_ client: IMKTextInput!, _ bundleId: String!) {
        self.inputText = client
        self._bundleId = bundleId!
        super.init(client: RecentTextClient(""), recent: RecentTextClient("")) // dummy
    }
    override func bundleId() -> String! {
        return _bundleId
    }
    override func selectedRange() -> NSRange {
        return inputText.selectedRange()
    }
    override func string(
        from range: NSRange,
        actualRange: NSRangePointer
    ) -> String! {
        return inputText.string(from: range, actualRange: actualRange)
    }
    override func insertText(
        _ string: String,
        replacementRange rr: NSRange
    ) {
        inputText.insertText(string, replacementRange: rr)
    }
    override func sendBackspace() {
        let keyCode: CGKeyCode = 0x33
        let backspaceDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let backspaceUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        backspaceDown?.post(tap: .cghidEventTap)
        backspaceUp?.post(tap: .cghidEventTap)
    }
}
