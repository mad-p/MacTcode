//
//  MazegakiHit.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

import Foundation

/// 特定の読み、活用部分に対応する候補全体を表わす
class MazegakiHit: Comparable {
    var yomi: [String] = []
    var found: Bool = false // 見つかったかどうか
    var key: String = ""    // dictを見るときのキー
    var length: Int = 0     // 読みの長さ
    var offset: Int = 0     // 活用部分の長さ
    var candidateString: [String]? = nil

    func candidates() -> [String] {
        if let ret = candidateString {
            return ret
        }
        if found {
            // LRU学習データを優先、なければ通常辞書を使用
            if let entry = MazegakiDict.i.lruDict[key] ?? MazegakiDict.i.dict[key] {
                let inflection = yomi.suffix(offset).joined()
                var cand = entry.components(separatedBy: "/")
                if !cand.isEmpty {
                    cand = cand.filter({ $0 != ""})
                    cand = cand.map { $0 + inflection }
                    candidateString = cand
                    return cand
                }
            }
        }
        candidateString = []
        return []
    }
    func duplicate() -> MazegakiHit {
        let newHit = MazegakiHit()
        newHit.yomi = yomi
        newHit.found = found
        newHit.key = key
        newHit.length = length
        newHit.offset = offset
        return newHit
    }
    static func < (lhs: MazegakiHit, rhs: MazegakiHit) -> Bool {
        return lhs.offset < rhs.offset ||
        lhs.length > rhs.length
    }

    static func == (lhs: MazegakiHit, rhs: MazegakiHit) -> Bool {
        return lhs.found == rhs.found &&
        lhs.yomi == rhs.yomi &&
        lhs.key == rhs.key &&
        lhs.length == rhs.length &&
        lhs.offset == rhs.offset
    }
}
