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
    private var candidatesWindow: IMKCandidates = IMKCandidates()
    private var firstStroke: Int? = nil
    private var firstChar: String? = nil
    private let recentText = RecentText("")
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
        NSLog("TcodeInputController: init")
    }
    
    fileprivate func reset() {
        firstStroke = nil
        firstChar = nil
    }
    
    /*
    fileprivate func commitTranslation(_ string: String, client: any IMKTextInput,
                                       inputLength: Int,
                                       cursor: NSRange, replaceRange: NSRange,
                                       useBackspace: Bool, consumeRecent: Bool) {
        if useBackspace {
            NSLog("send backspace")
            DispatchQueue.global().async {
                for _ in 0..<inputLength {
                    self.sendBackspace()
                    usleep(100000) // 0.1 sec
                }
                DispatchQueue.main.async {
                    client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                }
            }
        } else {
            if cursor.length > 0 {
                client.insertText(string, replacementRange: cursor)
            } else {
                let (location, length) = if cursor.location >= inputLength {
                    (cursor.location - inputLength, inputLength)
                } else {
                    (0, NSNotFound)
                }
                client.insertText(string, replacementRange: NSRange(location: location, length: length))
            }
        }
        if consumeRecent {
            recentChars.removeLast(inputLength)
            recentChars += string.map { String($0) }
            recentChars = recentChars.suffix(TcodeInputController.maxRecent)
        } else {
            recentChars = []
        }
    }*/
    
    /*
    fileprivate func postfixMazegaki(_ client: any IMKTextInput, inflection: Bool) -> Bool {
        let cursor = client.selectedRange()
        var consumeRecent = true
        var useBackspace = false
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)

        var mazegaki: Mazegaki
        
        if cursor.length == 0 {
            // mazegaki henkan from recentChars
            let text = recentChars.joined()
            NSLog("Online mazegaki from \(text)")
            mazegaki = Mazegaki(text, inflection: inflection, fixed: false)
            if cursor.location == NSNotFound {
                useBackspace = true
            }
        } else {
            // mazegaki henkan from selection
            if let text = client.string(from: cursor, actualRange: &replaceRange) {
                NSLog("Offline mazegaki \(text)")
                mazegaki = Mazegaki(text, inflection: false, fixed: true)
                consumeRecent = false
            } else {
                return true
            }
        }
    
        let hit = mazegaki.find(nil)
        if hit == nil {
            return true
        }
        let candidates = hit!.candidates()
        if candidates.isEmpty {
            return true
        }
        
        if candidates.count == 1 {
            NSLog("Mazegaki: sole candidate: \(candidates.first!)")
            commitTranslation(candidates.first!, client: client, inputLength: hit!.length, cursor: cursor, replaceRange: replaceRange, useBackspace: useBackspace, consumeRecent: consumeRecent)
        } else {
            NSLog("Mazegaki: more than one candidates: \(candidates)")
        }
        
        return true
    }
     */
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // get client to insert
        guard let client = sender as? IMKTextInput else {
            return false
        }
        
        let inputEvent = Translator.translate(event: event)
        var command = TcodeMap.map.lookup(input: inputEvent)
        while true {
            let baseInputText = BaseInputText(client: client, recent: recentText)
            switch command {
            case .passthrough:
                return false
            case .processed:
                return true
            case .text(let string, let array):
                baseInputText.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return true
            case .action(let action):
                command = action.execute(client: baseInputText)
            }
        }
        /*NOTREACHED*/
    }

}

/// クライアントのカーソル周辺の文字列、もし得られなければrecentCharsを扱うMyInputText
class BaseInputText: MyInputText {
    let client: IMKTextInput
    let recent: RecentText
    var useRecent: Bool = false
    init(client: IMKTextInput!, recent: RecentText) {
        self.client = client
        self.recent = recent
        let cursor = client.selectedRange()
        useRecent = (cursor.location == NSNotFound)
    }
    func selectedRange() -> NSRange {
        if useRecent {
            return recent.selectedRange()
        } else {
            return client.selectedRange()
        }
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer!
    ) -> String! {
        if useRecent {
            return recent.string(from: range, actualRange: actualRange)
        } else {
            return client.string(from: range, actualRange: actualRange)
        }
    }
    func insertText(
        _ string: String!,
        replacementRange rr: NSRange
    ) {
        if useRecent {
            recent.insertText(string, replacementRange: rr)
        } else {
            recent.append(string)
            client.insertText(string, replacementRange: rr)
        }
    }
    
    func sendBackspace() {
        if useRecent {
            recent.sendBackspace()
        } else {
            let keyCode: CGKeyCode = 0x33
            let backspaceDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            let backspaceUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            
            backspaceDown?.post(tap: .cghidEventTap)
            backspaceUp?.post(tap: .cghidEventTap)
        }
    }
}

class RecentText: MyInputText {
    static let maxLength: Int = 20
    var text: String
    init(_ string: String) {
        self.text = string
    }
    func selectedRange() -> NSRange {
        return NSRange(location: text.count, length: 0)
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer!
    ) -> String! {
        let from = text.index(text.startIndex, offsetBy: range.location)
        let to = text.index(text.startIndex, offsetBy: range.location + range.length)
        actualRange.pointee.location = range.location
        actualRange.pointee.length = range.length
        return String(text[from..<to])
    }
    func insertText(
        _ newString: String!,
        replacementRange rr: NSRange
    ) {
        let from = text.index(text.startIndex, offsetBy: rr.location)
        let to = text.index(text.startIndex, offsetBy: rr.location + rr.length)
        text.replaceSubrange(from..<to, with: newString)
        trim()
    }
    func trim() {
        let m = RecentText.maxLength
        if text.count > m {
            let newStart = text.index(text.endIndex, offsetBy: -m)
            text.replaceSubrange(text.startIndex..<newStart, with: "")
        }
    }
    func sendBackspace() {
        if text.count > 0 {
            text.removeLast()
        }
    }
    func append(_ newString: String) {
        text.append(newString)
        trim()
    }
}
