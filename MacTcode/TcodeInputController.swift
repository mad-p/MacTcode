//
//  TcodeInputController.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Cocoa
import InputMethodKit

@objc(TcodeInputController)
class TcodeInputController: IMKInputController, Controller {
    var modeStack: [Mode]
    var candidateWindow: IMKCandidates
    let client: Any!
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        modeStack = [TcodeMode()]
        client = inputClient
        candidateWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
        setupCandidateWindow()
        NSLog("TcodeInputController: init")
    }
    
    func setupCandidateWindow() {
        candidateWindow.setSelectionKeys([
            kVK_ANSI_J,
            kVK_ANSI_K,
            kVK_ANSI_L,
            kVK_ANSI_Semicolon,
            kVK_ANSI_1,
            kVK_ANSI_2,
            kVK_ANSI_3,
            kVK_ANSI_4,
            kVK_ANSI_5,
            kVK_ANSI_6,
            kVK_ANSI_7,
            kVK_ANSI_8,
            kVK_ANSI_9,
            kVK_ANSI_0,
        ])
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        let inputEvent = Translator.translate(event: event)
        return mode.handle(inputEvent, client: ClientWrapper(client), controller: self)
    }
    
    override func candidates(_ sender: Any!) -> [Any]! {
        if let modeWithCandidates = mode as? ModeWithCandidates {
            return modeWithCandidates.candidates(sender)
        } else {
            NSLog("*** TcodeInputController.candidates: called for non-ModeWithCandidates???")
            return []
        }
    }
    
    override func candidateSelected(_ candidateString: NSAttributedString!) {
        if let modeWithCandidates = mode as? ModeWithCandidates {
            if let client = self.client as? IMKTextInput {
                modeWithCandidates.candidateSelected(candidateString, client: ClientWrapper(client))
            } else {
                NSLog("*** TcodeInputController.candidateSelected: client is not IMKTextInput???")
            }
        } else {
            NSLog("*** TcodeInputController.candidateSelected: called for non-ModeWithCandidates???")
        }
    }
    
    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        if let modeWithCandidates = mode as? ModeWithCandidates {
            modeWithCandidates.candidateSelectionChanged(candidateString)
        } else {
            NSLog("*** TcodeInputController.candidates: called for non-ModeWithCandidates???")
        }
    }
 
    var mode: Mode {
        get {
            modeStack.first!
        }
    }
    func pushMode(_ mode: Mode) {
        modeStack = [mode] + modeStack
    }
    func popMode() {
        if modeStack.count > 1 {
            modeStack.removeFirst()
        }
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
    func handle(_ inputEvent: InputEvent, client: Client!, controller: Controller) -> Bool {
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
                command = action.execute(client: baseInputText, mode: self, controller: controller)
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
