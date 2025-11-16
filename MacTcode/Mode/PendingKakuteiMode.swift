//
//  PendingKakutei.swift
//  MacTcode
//
//  保留中の確定を表現するクラス
//  変換を確定した後、キャンセル可能な期間中の状態を管理する
//

import Foundation

/// 保留中の確定
class PendingKakuteiMode: Mode {
    /// コントローラを覚えておく
    let controller: Controller
    
    /// この時刻になったら受容されたと判定する時刻
    let acceptedTimeout: Date
    
    /// 変換の元となった文字列（キャンセル時に戻す）
    let yomiString: String
    
    /// 変換後、まだ受容されていない文字列（キャンセル時に削除して yomiString に置き換える）
    let kakuteiString: String
    
    /// 受容されたときに学習データのメンテナンスのために呼び出される処理
    let onAccepted: (_ parameter: Any?) -> Void
    
    /// onAcceptedに渡すパラメータ
    let parameter: Any?
    
    /// イニシャライザ
    /// - Parameters:
    ///   - timeout: 受容判定時刻
    ///   - yomi: 変換元文字列
    ///   - kakutei: 変換後文字列
    ///   - onAccepted: 受容時のハンドラ
    init(controller: Controller, yomi: String, kakutei: String,
         onAccepted: @escaping (_ parameter: Any?) -> Void, parameter: Any? = nil) {
        self.controller = controller
        self.acceptedTimeout = Date().addingTimeInterval(UserConfigs.shared.system.cancelPeriod)
        self.yomiString = yomi
        self.kakuteiString = kakutei
        self.onAccepted = onAccepted
        self.parameter = parameter
    }
    
    /// clientは変更しない
    func wrapClient(_ client: ContextClient!) -> ContextClient! {
        return client
    }
    
    /// controllerに自分を登録
    func install() {
        controller.pushMode(self)
    }
    
    func uninstall() {
        controller.popMode(self)
    }
    
    func reset() {
        uninstall()
    }
    
    /// 現在時刻でタイムアウトしているかチェック
    /// - Returns: タイムアウトしていればtrue
    func isTimedOut() -> Bool {
        return Date() >= acceptedTimeout
    }
    
    /// 受容処理を実行
    func accept() {
        if let param = parameter {
            Log.i("accepted \(yomiString) -> \(kakuteiString); parameter = \(param)")
        } else {
            Log.i("accepted \(yomiString) -> \(kakuteiString); parameter = nil")
        }
        uninstall()
        onAccepted(parameter)
    }
    
    /// PendingKakuteiをキャンセルする
    /// - Parameter client: クライアント
    func cancel(client: ContextClient) {
        Log.i("cancelPendingKakutei: yomi=\(yomiString), kakutei=\(kakuteiString)")
        
        // kakuteiStringを削除してyomiStringに置き換える
        // YomiContextを作ってClientContext.replaceYomiにまかせる
        let yomiContext = YomiContext(string: kakuteiString, range: NSRange(), fromSelection: false, fromMirror: true)
        Log.i("about to replaceYomi: yomi=\(yomiString), kakutei=\(kakuteiString)")
        let backspaceCount = client.replaceYomi(yomiString, length: kakuteiString.count, from: yomiContext)
        uninstall()
        controller.setBackspaceIgnore(backspaceCount)
    }
    
    func handle(_ inputEvent: InputEvent, client: ContextClient!) -> HandleResult {
        // PendingKakuteiの処理
        if self.isTimedOut() {
            // タイムアウトしている場合は受容
            Log.i("handle: pendingKakutei timed out, accepting")
            accept()
            return .forward
        }
        // キャンセル期間内
        // キャンセルキーの場合はキャンセル処理を実行して入力イベントを消費
        if inputEvent.type == .delete ||
            inputEvent.type == .control_g ||
            inputEvent.type == .escape {
            Log.i("handle: cancel key detected, canceling pendingKakutei")
            cancel(client: client)
            return .processed  // イベントを消費
        } else {
            // キャンセルキー以外の入力イベントはキャンセル期間を終了し、受容する
            Log.i("handle: non-cancel key, accepting pendingKakutei")
            accept()
            // そのまま次の処理に進む（イベントは消費しない）
            return .forward
        }
    }
}
