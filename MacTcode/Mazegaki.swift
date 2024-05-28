//
//  Mazegaki.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

import Cocoa

final class MazegakiDict {
    static let i = MazegakiDict()
    
    var dict: [String: String] = [:]
    static let inflectionMark = "—"
    
    private init() {
        NSLog("Read mazegaki dictionary...")
        if let mazedic = Config.loadConfig(file: "mazegaki.dic") {
            for line in mazedic.components(separatedBy: .newlines) {
                let kv = line.components(separatedBy: " ")
                if kv.count == 2 {
                    dict[kv[0]] = kv[1]
                } else {
                    if line.count > 0 {
                        NSLog("Invalid mazegaki.dic line: \(line)")
                    }
                }
            }
        }
        NSLog("\(dict.count) mazegaki entries read")
    }
}

class Mazegaki {
    var yomi: [String] // 読み部分の文字列、各要素は1文字
    var inflection: Bool // 活用語をさがすかどうか
    var fixed: Bool // 読み長さが固定かどうか
    var found: Bool // 見つかったかどうか
    var max: Int // 読みの最大長さ。fixedの場合はyomiの長さと同じ
    var length: Int // 候補が見つかったときの長さ
    var offset: Int // 候補が見つかったときの活用部分の長さ
    
    init(_ text: String, inflection: Bool, fixed: Bool) {
        yomi = text.map { String($0) }
        length = 0
        offset = 0
        self.inflection = inflection
        self.fixed = fixed
        self.max = yomi.count
        self.length = self.max
        found = false
    }
    
    // 検索キーを文字列として返す
    func key(_ i: Int, offset: Int = 0) -> String? {
        if i > yomi.count || i == 0 || offset >= i {
            return nil
        }
        var chars = yomi.suffix(i)
        if offset > 0 && chars.count > offset {
            chars = chars.dropLast(offset)
            chars.append(MazegakiDict.inflectionMark)
        }
        if chars.count > 0 {
            return chars.joined()
        } else {
            return nil
        }
    }
    
    // max文字以内かつ候補がある最大長さの読みを見つける
    // 活用しないバージョン
    func find(start: Int = 0) -> Bool {
        var i = start == 0 ? length : start
        while i > 0 {
            if let k = key(i) {
                if MazegakiDict.i.dict[k] != nil {
                    length = i
                    found = true
                    offset = 0
                    return true
                }
            }
            i -= 1
        }
        return false
    }
}
