//
//  TcodeInputController.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Cocoa
import InputMethodKit

@objc(TcodeInputController)
class TcodeInputController: IMKInputController {
    // private var candidatesWindow: IMKCandidates = IMKCandidates()
    let mode: TcodeMode
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        // self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        mode = TcodeMode()
        super.init(server: server, delegate: delegate, client: inputClient)
        NSLog("TcodeInputController: init")
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        let inputEvent = Translator.translate(event: event)
        return mode.handle(inputEvent, client: ClientWrapper(client))
    }

}

class TcodeMode {
    var recentText = RecentTextClient("")
    var pending: [InputEvent] = []
    func reset() {
        recentText = RecentTextClient("")
        pending = []
    }
    func handle(_ inputEvent: InputEvent, client: Client!) -> Bool {
        let baseInputText = MirroringClient(client: client, recent: recentText)
        let seq = pending + [inputEvent]
        pending = []
        // TODO pendingを処理するコマンドだけ、resolveより前に処理しなければならない
        // - spaceでpendingを送る
        // - escapeで取り消す
        var command: Command? = nil
        if let topLevelEntry = TopLevelMap.map.lookup(input: inputEvent) {
            if ResetAllStateAction.isResetAction(entry: topLevelEntry) {
                reset()
                return true
            }
            command = topLevelEntry
        }
        if command == nil {
            command = KeymapResolver.resolve(keySequence: seq, keymap: TcodeKeymap.map)
        }
        while command != nil {
            NSLog("execute command \(command!);  recentText = \(recentText.text)")
            
            switch command! {
            case .passthrough:
                return false
            case .processed:
                return true
            case .pending:
                pending = seq
                return true
            case .text(let string):
                baseInputText.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return true
            case .action(let action):
                command = action.execute(client: baseInputText, input: seq)
            case .keymap(_):
                // can't happen
                NSLog("handler have Command.keymap???")
                return false
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
        actualRange: NSRangePointer!
    ) -> String! {
        return client.string(from: range, actualRange: actualRange)
    }
    func insertText(
        _ string: String!,
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
