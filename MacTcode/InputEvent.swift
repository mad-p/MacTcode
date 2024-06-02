//
//  InputEvent.swift
//  MacTcode
//
//  Created by maeda on 2024/06/02.
//

import Foundation

/// 入力イベントタイプ
enum InputEventType {
    /// プリンタブル文字
    /// - Parameter Int: 入力した文字がTコード文字の場合、そのキー番号
    case printable(_ key: Int?)
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
struct InputEvent {
    /// タイプ
    var type: InputEventType
    /// キーに対応する文字がある場合、その文字
    var text: String?
}
