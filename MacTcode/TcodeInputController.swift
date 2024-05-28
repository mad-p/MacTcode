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
    private var recentChars: [String] = []
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
        NSLog("TcodeInputController: init")
    }
    
    func reset() {
        firstStroke = nil
        firstChar = nil
    }
    fileprivate func postfixBushu(_ client: any IMKTextInput) -> Bool {
        // postfix bushu
        let cursor = client.selectedRange()
        var ch1: String? = nil
        var ch2: String? = nil
        var consumeRecent = true
        var useBackspace = false
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)
        let emptyRange = NSRange(location: NSNotFound, length: NSNotFound)

        if cursor.length == 2 {
            // bushu henkan from selection
            if let text = client.string(from: cursor, actualRange: &replaceRange) {
                let chars = text.map { String($0) }
                ch1 = chars[0]
                ch2 = chars[1]
                if (ch1 != nil) && (ch2 != nil) {
                    NSLog("Offline bushu \(ch1!)\(ch2!)")
                } else {
                    NSLog("offline bushu but no chars")
                }
                consumeRecent = false
            }
        } else {
            // bushu henkan from recentChars
            NSLog("Online bushu")
            if recentChars.count >= 2 {
                ch1 = recentChars[recentChars.count - 2]
                ch2 = recentChars[recentChars.count - 1]
            }
            if cursor.location == NSNotFound {
                useBackspace = true
            }
        }
        if (ch1 == nil) || (ch2 == nil) {
            NSLog("Bushu henkan: no input")
        } else {
            if let ch = TcodeBushu.bushu.compose(char1: ch1!, char2: ch2!) {
                NSLog("Bushu \(ch1!)\(ch2!) -> \(ch)")
                if useBackspace {
                    NSLog("send backspace")
                    sendBackspace()
                    Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                        self.sendBackspace()
                        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                            client.insertText(ch, replacementRange: emptyRange)
                        }
                    }
                    client.insertText(ch, replacementRange: emptyRange)
                } else {
                    NSLog("selected range: \(cursor.location), \(cursor.length)")
                    if cursor.length > 0 {
                        client.insertText(ch, replacementRange: cursor)
                    } else {
                        let location = cursor.location >= 2 ? cursor.location - 2 : 0
                        let length = cursor.location >= 2 ? 2 : NSNotFound
                        client.insertText(ch, replacementRange: NSRange(location: location, length: length))
                    }
                }
                if consumeRecent {
                    recentChars.removeLast(2)
                    recentChars.append(ch)
                }
            } else {
                NSLog("Bushu henkan no candidates for \(ch1!)\(ch2!)")
            }
        }
        return true
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // get client to insert
        guard let client = sender as? IMKTextInput else {
            return false
        }
        NSLog("event.keyCode = \(event.keyCode); event.characters = \(event.characters ?? "nil"); event.modifierFlags = \(event.modifierFlags)")
        
        if !event.modifierFlags.isEmpty {
            reset()
            return false
        }
        if let text = event.characters, text.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation }) {
            if let stroke = TcodeTable.translateKey(text: text) {
                if let first = firstStroke {
                    // second stroke
                    if first == 26 && stroke == 23 {
                        reset()
                        return postfixBushu(client)
                    }
                    if let str = TcodeTable.lookup(first: first, second: stroke) {
                        NSLog("Submit \(str)")
                        recentChars.append(str)
                        if recentChars.count > 8 {
                            recentChars.removeFirst()
                        }
                        client.insertText(str, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                        reset()
                        return true
                    } else {
                        NSLog("Undefined stroke \(first) \(stroke)")
                        return true
                    }
                } else {
                    // first stroke
                    firstStroke = stroke
                    firstChar = event.characters!
                    return true
                }
            }
        }
        
        // non-tcode key
        switch(event.keyCode) {
        case 49: // Space -- submit first stroke
            if firstChar != nil {
                client.insertText(firstChar, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                reset()
                return true
            } else {
                return false
            }
        case 53: // Escape -- cancel first stroke
            reset()
            return true
        default:
            return false
        }

        /*NOTREACHED*/
    }
    
    func sendBackspace() {
        // バックスペースのキーコード（8）を定義
        let keyCode: CGKeyCode = 0x33
        
        // バックスペースキー押下イベントを作成
        let backspaceDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        // バックスペースキー解放イベントを作成
        let backspaceUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        // イベントを送信
        backspaceDown?.post(tap: .cghidEventTap)
        backspaceUp?.post(tap: .cghidEventTap)
    }
}

