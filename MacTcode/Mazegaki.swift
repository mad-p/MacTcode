//
//  Mazegaki.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

// 交ぜ書き変換アルゴリズム
// tc-mazegaki.el の割と新しいバージョンのアルゴリズムを再現。
// 元コードはGPLだが、コードコピーはしていないので、MITライセンスで配布できるはず。

import Cocoa
import InputMethodKit

final class MazegakiDict {
    static let i = MazegakiDict()
    
    var dict: [String: String] = [:]
    static let inflectionMark = "—"
    
    func readDictionary() {
        NSLog("Read mazegaki dictionary...")
        dict = [:]
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
    
    private init() {
        readDictionary()
    }
}

class MazegakiHit {
    var found: Bool = false // 見つかったかどうか
    var key: String = ""    // dictを見るときのキー
    var length: Int = 0     // 読みの長さ
    var offset: Int = 0     // 活用部分の長さ
    
    func candidates() -> [String] {
        if !found {
            return []
        }
        if let dictEntry = MazegakiDict.i.dict[key] {
            var cand = dictEntry.components(separatedBy: "/")
            if cand.isEmpty {
                return []
            }
            if cand.first == "" {
                cand.removeFirst()
            }
            if cand.last == "" {
                cand.removeLast()
            }
            return cand
        }
        return []
    }
}

class Mazegaki {
    static var maxInflection = 4 // 活用部分の最大長
    static var inflectionCharsMin = 0x3041 // 活用部分に許される文字コードポイントの下限
    static var inflectionCharsMax = 0x30fe // 活用部分に許される文字上限
    static var nonYomiCharacters =
        ["、", "。", "，", "．", "・", "「", "」", "（", "）"] // 読み部分に許されない文字
    
    let yomi: [String] // 読み部分の文字列、各要素は1文字
    let inflection: Bool // 活用語をさがすかどうか
    let fixed: Bool // 読み長さが固定かどうか
    let max: Int // 読みの最大長さ。fixedの場合はyomiの長さと同じ
    
    init(_ text: String, inflection: Bool, fixed: Bool) {
        yomi = text.map { String($0) }
        let l = yomi.count
        var m = l
        for i in 0..<yomi.count {
            if Mazegaki.nonYomiCharacters.contains(yomi[l - i - 1]) {
                m = i
                break
            }
        }
        self.max = m
        self.inflection = inflection
        self.fixed = fixed
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
    // from:に前回のヒット結果が指定された場合、それよりも短い読みをさがす
    func find(_ from: MazegakiHit?) -> MazegakiHit? {
        let result = MazegakiHit()
        result.found = false
        var i = from != nil ? from!.length - 1 : max
        while i > 0 {
            if fixed && i != max {
                return result
            }
            if let k = key(i) {
                if MazegakiDict.i.dict[k] != nil {
                    result.key = k
                    result.length = i
                    result.found = true
                    result.offset = 0
                    return result
                }
            }
            i -= 1
        }
        return result
    }
}

class PostfixMazegakiAction: Action {
    func execute(client: MyInputText) -> Command {
        return .processed
    }
}

