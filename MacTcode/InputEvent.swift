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
    var event: NSEvent
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
        case .printable:
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
