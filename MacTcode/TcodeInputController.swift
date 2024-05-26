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
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
        NSLog("TcodeInputController: init")
    }
    
    func reset() {
        firstStroke = nil
        firstChar = nil
        NSLog("reset")
    }
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // get client to insert
        guard let client = sender as? IMKTextInput else {
            return false
        }
        NSLog("event.keyCode = \(event.keyCode); firstChar = \(firstChar ?? "nil")")
        
        if !event.modifierFlags.isEmpty {
            reset()
            return false
        }
        if let stroke = TcodeTable.translateKey(event: event) {
            if let first = firstStroke {
                // second stroke
                NSLog("Second stroke \(stroke)")
                if let str = TcodeTable.lookup(i: first, j: stroke) {
                    NSLog("Submit \(str)")
                    client.insertText(str, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                    reset()
                    return true
                } else {
                    NSLog("Undefined stroke \(first) \(stroke)")
                    return true
                }
            } else {
                // first stroke
                NSLog("First stroke \(stroke)")
                firstStroke = stroke
                firstChar = event.characters!
                return true
            }
        } else {
            // non-tcode key
            switch(event.keyCode) {
            case 49: // Space -- submit first stroke
                client.insertText(firstChar, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                reset()
                return true
            case 53: // Escape -- cancel first stroke
                reset()
                return true
            default:
                return false
            }
        }
        /*NOTREACHED*/
    }
}

