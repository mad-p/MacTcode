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
    var cache: [String]? = nil

    func candidates() -> [String] {
        if let ret = cache {
            return ret
        }
        if found {
            if let dictEntry = MazegakiDict.i.dict[key] {
                let inflection = yomi.suffix(offset).joined()
                var cand = dictEntry.components(separatedBy: "/")
                if !cand.isEmpty {
                    cand = cand.filter({ $0 != ""})
                    cand = cand.map { $0 + inflection }
                    cache = cand
                    return cand
                }
            }
        }
        cache = []
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
