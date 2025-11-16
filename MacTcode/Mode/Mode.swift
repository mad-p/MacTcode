//
//  Mode.swift
//  MacTcode
//
//  Created by maeda on 2024/06/04.
//

import Cocoa
import InputMethodKit

enum HandleResult {
    case processed   // 処理完了した
    case passthrough // すべてのモードをスルーし、アプリケーションに渡す
    case forward     // 次のモードに処理を渡す
}

/// 入力モード
protocol Mode: AnyObject {
    /// 入力イベントを処理する
    func handle(_ inputEvent: InputEvent, client: ContextClient!) -> HandleResult
    /// すべての状態を初期状態にする
    func reset()
    /// Clientに機能を追加する
    func wrapClient(_ client: ContextClient!) -> ContextClient!
}
