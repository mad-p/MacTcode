//
//  Translator.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Cocoa
import InputMethodKit

/// NSEventをInputEventに変換する
class Translator {
    static var layout: [String] {
        return UserConfigs.shared.system.keyboardLayoutMapping
    }
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
        Log.i("event.keyCode = \(event.keyCode); event.characters = \(event.characters ?? "nil"); event.modifierFlags = \(event.modifierFlags)")
        
        let text = event.characters
        let printable = if text != nil {
            text!.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isMathSymbol })
        } else {
            false
        }
        
        var flags = ""
        if event.modifierFlags.contains(.option) {
            flags.append(" options")
        }
        if event.modifierFlags.contains(.command) {
            flags.append(" command")
        }
        if event.modifierFlags.contains(.function) {
            flags.append(" function")
        }
        if event.modifierFlags.contains(.control) {
            flags.append(" control")
        }
        Log.i(" modifierFlags: \(flags)")
        
        var type: InputEventType = .unknown
        if event.modifierFlags.contains(.option)
            || event.modifierFlags.contains(.command)
        {
            type = .unknown
        } else if printable {
            if text != nil && " ',.-=/;".contains(text!) && event.modifierFlags.contains(.control) {
                type = .control_punct
            } else if text == "\u{07}" && event.modifierFlags.contains(.control) {
                type = .control_g
            } else if text == " " {
                type = .space
            } else {
                type = .printable
            }
        } else {
            switch(text) {
            case " ":      type = .space
            case "\u{08}": type = .delete
            case "\n":     type = .enter
            case "\u{1b}": type = .escape
            case "\u{07}": type = .control_g
            case "\u{09}": type = .tab
            default:
                Log.i("Translate by keycode")
                switch(Int(event.keyCode)) {
                case kVK_Return:     type = .enter
                case kVK_Tab:        type = .tab
                case kVK_LeftArrow:  type = .left
                case kVK_RightArrow: type = .right
                case kVK_DownArrow:  type = .down
                case kVK_UpArrow:    type = .up
                case kVK_Delete:     type = .delete
                default:
                    Log.i("  unknown keycode")
                    type = .unknown
                }
            }
        }
        let event = InputEvent(type: type, text: text, event: event)
        Log.i("  translated to \(event)")
        return event
    }
}
