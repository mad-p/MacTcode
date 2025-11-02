//
//  PendingKakutei.swift
//  MacTcode
//
//  保留中の確定を表現するクラス
//  変換を確定した後、キャンセル可能な期間中の状態を管理する
//

import Foundation

/// 保留中の確定
class PendingKakutei {
    /// この時刻になったら受容されたと判定する時刻
    let acceptedTimeout: Date

    /// 変換の元となった文字列（キャンセル時に戻す）
    let yomiString: String

    /// 変換後、まだ受容されていない文字列（キャンセル時に削除して yomiString に置き換える）
    let kakuteiString: String

    /// 受容されたときに学習データのメンテナンスのために呼び出される処理
    let onAccepted: () -> Void

    /// イニシャライザ
    /// - Parameters:
    ///   - timeout: 受容判定時刻
    ///   - yomi: 変換元文字列
    ///   - kakutei: 変換後文字列
    ///   - onAccepted: 受容時のハンドラ
    init(timeout: Date, yomi: String, kakutei: String, onAccepted: @escaping () -> Void) {
        self.acceptedTimeout = timeout
        self.yomiString = yomi
        self.kakuteiString = kakutei
        self.onAccepted = onAccepted
    }

    /// 現在時刻でタイムアウトしているかチェック
    /// - Returns: タイムアウトしていればtrue
    func isTimedOut() -> Bool {
        return Date() >= acceptedTimeout
    }

    /// 受容処理を実行
    func accept() {
        onAccepted()
    }
}
