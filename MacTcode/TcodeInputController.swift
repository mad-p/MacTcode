//
//  TcodeInputController.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Cocoa
import InputMethodKit

@objc(TcodeInputController)
class TcodeInputController: IMKInputController, ModeHolder {
    // private var candidatesWindow: IMKCandidates = IMKCandidates()
    var mode: Mode

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
        return mode.handle(inputEvent, client: ClientWrapper(client), modeHolder: self)
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
    }
}

class TcodeMode: Mode, MultiStroke {
    var recentText = RecentTextClient("")
    var pending: [InputEvent] = []
    var map = TcodeKeymap.map
    var quickMap: Keymap = TopLevelMap.map
    func resetPending() {
        pending = []
    }
    func reset() {
        recentText = RecentTextClient("")
        resetPending()
    }
    func removeLastPending() {
        if pending.count > 0 {
            pending.removeLast()
        }
    }
    func handle(_ inputEvent: InputEvent, client: Client!, modeHolder: ModeHolder) -> Bool {
        let baseInputText = MirroringClient(client: client, recent: recentText)
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
            NSLog("execute command \(command!);  recentText = \(recentText.text)")
            
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
                baseInputText.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return true
            case .action(let action):
                command = action.execute(client: baseInputText, mode: self, modeHolder: modeHolder)
                resetPending()
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
