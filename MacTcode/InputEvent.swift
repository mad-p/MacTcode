//
//  InputEvent.swift
//  MacTcode
//
//  Created by maeda on 2024/06/02.
//

import Cocoa

/// 入力イベントタイプ
enum InputEventType {
    /// プリンタブル文字
    case printable
    /// エンターキー
    case enter
    /// 矢印キー
    case left, right, up, down
    /// スペースバー
    case space
    /// deleteキーまたは ^H
    case delete
    /// escapeキーまたは^[
    case escape
    /// control + ',./=-;`
    case control_punct
    /// それ以外
    case unknown
}

/// 入力イベント
struct InputEvent: Hashable, CustomStringConvertible {
    /// タイプ
    var type: InputEventType
    /// キーに対応する文字がある場合、その文字
    var text: String?
    /// 元となったイベント
    var event: NSEvent?
    /// ログ用表現
    var description: String {
        let t = if text == nil { "" } else { ", \(text!)" }
        return "InputEvent(\(type)\(t))"
    }
    
    /// printableのときのみtextを考慮する
    static func == (lhs: InputEvent, rhs: InputEvent) -> Bool {
        if lhs.type != rhs.type {
            return false
        }
        switch lhs.type {
        case .printable, .control_punct:
            return (lhs.text == rhs.text)
        default:
            return true
        }
    }
    
    /// printableのときのみtextを考慮する
    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        switch type {
        case .printable:
            hasher.combine(text)
        default:
            break
        }
    }
}

/// NSEventをInputEventに変換する
class Translator {
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
            default:
                Log.i("Translate by keycode")
                switch(event.keyCode) {
                case 36:  type = .enter
                case 123: type = .left
                case 124: type = .right
                case 125: type = .down
                case 126: type = .up
                case 51:  type = .delete
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
