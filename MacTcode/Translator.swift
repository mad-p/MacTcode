//
//  Translator.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

/// NSEventをInputEventに変換する
class Translator {
    static let nKeys = 40
    static var layout: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "'", ",", ".", "p", "y", "f", "g", "c", "r", "l",
        "a", "o", "e", "u", "i", "d", "h", "t", "n", "s",
        ";", "q", "j", "k", "x", "b", "m", "w", "v", "z",
    ]
    static func strToKey(_ string: String!) -> Int? {
        return layout.firstIndex(of: string)
    }
    static func keyToStr(_ key: Int) -> String? {
        if (0..<nKeys).contains(key) {
            return layout[key]
        } else {
            return nil
        }
    }
    static func translate(event: NSEvent!) -> InputEvent {
        NSLog("event.keyCode = \(event.keyCode); event.characters = \(event.characters ?? "nil"); event.modifierFlags = \(event.modifierFlags)")
        
        let text = event.characters
        let printable = if text != nil {
            text!.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation })
        } else {
            false
        }
        
        let type: InputEventType = if printable {
            if text == " " {
                .space
            } else {
                .printable(strToKey(text!))
            }
        } else {
            switch(text) {
            case " ": .space
            case "\010": .delete
            case "\n": .enter
            case "\033": .escape
            default:
                switch(event.keyCode) {
                case 38: .enter
                case 123: .left
                case 124: .right
                case 125: .down
                case 126: .up
                case 51: .delete
                default: .unknown
                }
            }
        }
        
        return InputEvent(type: type, text: text)
    }
}
