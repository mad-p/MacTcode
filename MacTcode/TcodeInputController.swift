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
    let mainloop: TcodeMainloop
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        // self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        mainloop = TcodeMainloop()
        super.init(server: server, delegate: delegate, client: inputClient)
        NSLog("TcodeInputController: init")
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        return mainloop.handle(event, client: Wrapper(client))
    }

}

class TcodeMainloop {
    let recentText = RecentText("")
    func handle(_ event: NSEvent!, client: MyInputText!) -> Bool {
        let inputEvent = Translator.translate(event: event)
        var command = TcodeKeymap.map.lookup(input: inputEvent)
        while true {
            NSLog("execute command \(command);  recentText = \(recentText.text)")
            let baseInputText = BaseInputText(client: client, recent: recentText)
            switch command {
            case .passthrough:
                return false
            case .processed:
                return true
            case .text(let string, _):
                baseInputText.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return true
            case .action(let action):
                command = action.execute(client: baseInputText)
            }
        }
        /*NOTREACHED*/
    }
}

/// IMKTextInputをMyInputTextに見せかけるラッパー
class Wrapper: MyInputText {
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

/// クライアントのカーソル周辺の文字列、もし得られなければrecentCharsを扱うMyInputText
/// clientをMyInputTextにしておくことで、テストのときにclientをspyとして使える
class BaseInputText: MyInputText {
    let client: MyInputText
    let recent: RecentText
    let target: MyInputText
    let useRecent: Bool
    init(client: MyInputText, recent: RecentText) {
        self.client = client
        self.recent = recent
        let cursor = client.selectedRange()
        (target, useRecent) = if cursor.location == NSNotFound {
            (recent, true)
        } else {
            (client, false)
        }
    }
    func selectedRange() -> NSRange {
        return target.selectedRange()
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer!
    ) -> String! {
        return target.string(from: range, actualRange: actualRange)
    }
    func insertText(
        _ string: String!,
        replacementRange rr: NSRange
    ) {
        target.insertText(string, replacementRange: rr)
        if !useRecent {
            recent.append(string)
        }
    }
    func sendBackspace() {
        target.sendBackspace()
    }
}
