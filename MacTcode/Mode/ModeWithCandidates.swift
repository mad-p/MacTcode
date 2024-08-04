//
//  ModeWithCandidates.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation

/// 変換候補を持つモード
protocol ModeWithCandidates {
    /// 変換候補Windowを表示する
    func showWindow()
    /// 変換候補を返す
    func candidates(_ sender: Any!) -> [Any]!
    /// 候補選択された
    func candidateSelected(_ candidateString: NSAttributedString!, client: Client!)
    /// 別の候補が選択された
    func candidateSelectionChanged(_ candidateString: NSAttributedString!)
}
