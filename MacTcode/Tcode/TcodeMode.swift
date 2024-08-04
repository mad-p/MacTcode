//
//  TcodeMode.swift
//  MacTcode
//
//  Created by maeda on 2024/08/05.
//

import Cocoa
import InputMethodKit

class TcodeMode: Mode, MultiStroke {
    var pending: [InputEvent] = []
    var map = TcodeKeymap.map
    var quickMap: Keymap = TopLevelMap.map
    func resetPending() {
        pending = []
    }
    func reset() {
        resetPending()
    }
    func removeLastPending() {
        if pending.count > 0 {
            pending.removeLast()
        }
    }
    func handle(_ inputEvent: InputEvent, client: Client!, controller: Controller) -> Bool {
        let seq = pending + [inputEvent]
        
        // 複数キーからなるキーシーケンスの途中でも処理するコマンドはquickMapに入れておく
        // - spaceでpendingを送る
        // - escapeで取り消す
        // - deleteで1文字消す
        var command: Command? =
        if let topLevelEntry = quickMap.lookup(input: inputEvent) {
            topLevelEntry
        } else {
            KeymapResolver.resolve(keySequence: seq, keymap: map)
        }
        while command != nil {
            Log.i("execute command \(command!)")
            
            switch command! {
            case .passthrough:
                resetPending()
                return false
            case .processed:
                resetPending()
                return true
            case .pending:
                pending = seq
                return true
            case .text(let string):
                resetPending()
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return true
            case .action(let action):
                command = action.execute(client: client, mode: self, controller: controller)
                resetPending()
            case .keymap(_):
                preconditionFailure("Keymap resolved to .keymap??")
            }
        }
        return true // can't happen
    }
}

/// IMKTextInputをMyInputTextに見せかけるラッパー
class ClientWrapper: Client {
    let client: IMKTextInput
    init(_ client: IMKTextInput!) {
        self.client = client
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
