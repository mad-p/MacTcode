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
    private var insertTextCalled: Bool = false
    init(_ client: IMKTextInput!, _ bundleId: String!) {
        self.inputText = client
        self._bundleId = bundleId!
        self.insertTextCalled = false
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
        self.insertTextCalled = true
        inputText.insertText(string, replacementRange: rr)
    }
    override func setMarkedText(
        _ string: String,
        selectionRange: NSRange,
        replacementRange: NSRange
    ) {
        inputText.setMarkedText(string, selectionRange: selectionRange, replacementRange: replacementRange)
    }

    override func sendBackspace() {
        let keyCode: CGKeyCode = 0x33
        let backspaceDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let backspaceUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        backspaceDown?.post(tap: .cghidEventTap)
        backspaceUp?.post(tap: .cghidEventTap)
    }

    override func sendDummyInsertMaybe() {
        if !insertTextCalled {
            let dummyInsertTextApps = UserConfigs.i.system.dummyInsertTextApps
            if let dummyMode = dummyInsertTextApps[_bundleId] {
                let dummyString = (dummyMode == "nul") ? "\0" : ""
                Log.i("sendDummyInsertMaybe: bundle=\(_bundleId ?? "nil"), mode=\(dummyMode)")
                inputText.insertText(dummyString, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
        }
    }
}
