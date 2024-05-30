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
    static var maxRecent = 10
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
        NSLog("TcodeInputController: init")
    }
    
    fileprivate func reset() {
        firstStroke = nil
        firstChar = nil
    }
    
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
    }
    
    fileprivate func postfixBushu(_ client: any IMKTextInput) -> Bool {
        // postfix bushu
        let cursor = client.selectedRange()
        var ch1: String? = nil
        var ch2: String? = nil
        var consumeRecent = true
        var useBackspace = false
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)

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
            if let ch = Bushu.i.compose(char1: ch1!, char2: ch2!) {
                NSLog("Bushu \(ch1!)\(ch2!) -> \(ch)")
                commitTranslation(ch, client: client, inputLength: 2, cursor: cursor, replaceRange: replaceRange, useBackspace: useBackspace, consumeRecent: consumeRecent)
            } else {
                NSLog("Bushu henkan no candidates for \(ch1!)\(ch2!)")
            }
        }
        return true
    }
    
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
                    
                    // function bindings
                    if first == 26 && stroke == 23 { // hu
                        reset()
                        return postfixBushu(client)
                    }
                    if first == 23 && stroke == 26 { // uh
                        reset()
                        return postfixMazegaki(client, inflection: false)
                    }
                    if first == 4 && stroke == 7 { // 58
                        reset()
                        return postfixMazegaki(client, inflection: true)
                    }
                    if let str = TcodeTable.lookup(first: first, second: stroke) {
                        NSLog("Submit \(str)")
                        recentChars.append(str)
                        recentChars = recentChars.suffix(10)
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

