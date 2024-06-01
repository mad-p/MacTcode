//
//  Translator.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

/// 入力イベントタイプ
enum InputEventType {
    /// プリンタブル文字
    /// - Parameter key: Int: 入力した文字がTコード文字の場合、そのキー番号
    case printable(Int?)
    /// エンターキー
    case enter
    /// 矢印キー
    case left, right, up, down
    /// スペースバー
    case space
    /// deleteキーまたは ^H
    case delete
    /// それ以外
    case unknown
}

/// 入力イベント
struct InputEvent {
    /// タイプ
    var type: InputEventType
    /// キーに対応する文字がある場合、その文字
    var text: String?
    /// 元となった生イベント
    var event: NSEvent
}

/// NSEventをInputEventに変換する
class Translator {
    static let nKeys = 40
    static var layout: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "'", ",", ".", "p", "y", "f", "g", "c", "r", "l",
        "a", "o", "e", "u", "i", "d", "h", "t", "n", "s",
        ";", "q", "j", "k", "x", "b", "m", "w", "v", "z",
    ]
    static func translate(event: NSEvent!) -> InputEvent {
        NSLog("event.keyCode = \(event.keyCode); event.characters = \(event.characters ?? "nil"); event.modifierFlags = \(event.modifierFlags)")
        
        let text = event.characters
        let printable = if text != nil {
            text!.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation })
        } else {
            false
        }
        
        let type: InputEventType = if printable {
            .printable(layout.firstIndex(of: text!))
        } else {
            switch(text) {
            case " ": .space
            case "\010": .delete
            case "\n": .enter
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
        
        return InputEvent(type: type, text: text, event: event)
    }
}
