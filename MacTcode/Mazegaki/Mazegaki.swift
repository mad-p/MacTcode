//
//  Mazegaki.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

// 交ぜ書き変換アルゴリズム
// tc-mazegaki.el の割と新しいバージョンのアルゴリズムを再現。
// 元コードはGPLだが、コードコピーはしていないので、MITライセンスで配布できるはず。

import Foundation

class Mazegaki {
    // UserConfigsから設定値を取得するためのcomputed properties
    static var maxInflection: Int { UserConfigs.shared.mazegaki.maxInflection }
    static var inflectionCharsMin = 0x3041 // 活用部分に許される文字コードポイントの下限
    static var inflectionCharsMax = 0x30fe // 活用部分に許される文字上限
    static var inflectionRange = inflectionCharsMin...inflectionCharsMax

    let yomi: [String] // 読み部分の文字列、各要素は1文字
    let inflection: Bool // 活用語をさがすかどうか
    let fixed: Bool // 読み長さが固定かどうか
    let max: Int // 読みの最大長さ。fixedの場合はyomiの長さと同じ
    let context: YomiContext

    init(_ context: YomiContext, inflection: Bool) {
        self.context = context
        let text = context.string
        self.fixed = context.fromSelection
        yomi = text.map { String($0) }
        self.max = yomi.count
        self.inflection = inflection
    }

    // 検索キーを文字列として返す
    func key(_ i: Int, offset: Int = 0) -> String? {
        if i > yomi.count || i == 0 || offset >= i {
            return nil
        }
        var chars = yomi.suffix(i)
        if offset > 0 && chars.count > offset {
            let infChars = chars.suffix(offset)
            if !infChars.allSatisfy({
                let charCode = $0.unicodeScalars.first!.value
                return Mazegaki.inflectionRange.contains(Int(charCode))
            }) {
                return nil
            }
            chars = chars.dropLast(offset)
            chars.append(MazegakiDict.inflectionMark)
        }
        if chars.count > 0 {
            let res: String = chars.joined()
            // Log.i("Mazegaki.key: yomi=\(yomi.joined())  i=\(i)  offset=\(offset) ->  result=\(res)")
            return res
        } else {
            return nil
        }
    }

    /// 全候補の可能性をすべて数えあげる
    func find() -> [MazegakiHit] {
        // 活用しないとき
        // - 最大長さを見つける
        // 活用するとき
        // - 全体の長さが同じときに、活用部分の長さが短い順で全部見つける
        var result: [MazegakiHit] = []
        let iRange = fixed ? [max] : (0..<max).map{ max - $0 }
        for i in iRange {
            let jRange = inflection ? (1..<i).map{$0} : [0]
            for j in jRange {
                if let k = key(i, offset: j) {
                    if MazegakiDict.i.dict[k] != nil {
                        let hit = MazegakiHit()
                        hit.yomi = yomi.suffix(i)
                        hit.key = k
                        hit.length = i
                        hit.found = true
                        hit.offset = j
                        result.append(hit)
                    }
                }
            }
        }
        return result.sorted()
    }

    /// 確定するコンビニメソッド
    func submit(hit: MazegakiHit, index: Int, client: Client, controller: Controller) -> Bool {
        if !hit.found || index >= hit.candidates().count {
            return false
        }
        return self.submit(hit: hit, string: hit.candidates()[index], client: client, controller: controller)
    }

    func submit(hit: MazegakiHit, string: String, client: Client, controller: Controller) -> Bool {
        guard let client = client as? ContextClient else {
            Log.i("★★Can't happen: Mazegaki.submit: client is not ContextClient")
            return false
        }
        if !hit.found {
            return false
        }
        let length = hit.length
        Log.i("Kakutei \(string)  client=\(type(of:client))")
        InputStats.shared.incrementMazegakiCount()
        client.replaceYomi(string, length: length, from: context)

        // LRU学習が有効な場合、PendingKakuteiを生成
        if UserConfigs.shared.mazegaki.lruEnabled {
            // 活用部分を除いた候補文字列を取得
            let inflection = hit.yomi.suffix(hit.offset).joined()
            let candidateWithoutInflection: String
            if string.hasSuffix(inflection) {
                candidateWithoutInflection = String(string.dropLast(inflection.count))
            } else {
                candidateWithoutInflection = string
            }

            let yomiString = hit.yomi.joined()
            let timeout = Date().addingTimeInterval(UserConfigs.shared.system.cancelPeriod)

            let pending = PendingKakutei(
                timeout: timeout,
                yomi: yomiString,
                kakutei: string,
                onAccepted: { [weak hit] in
                    // 受容時の処理: LRU学習データを更新
                    guard let hit = hit else { return }
                    MazegakiDict.i.updateLruEntry(key: hit.key, selectedCandidate: candidateWithoutInflection)
                }
            )
            controller.setPendingKakutei(pending)
        }

        return true
    }
}

class PostfixMazegakiAction: Action {
    var maxYomi: Int { UserConfigs.shared.mazegaki.maxYomi }
    let inflection : Bool
    init(inflection: Bool) {
        self.inflection = inflection
    }
    func execute(client: Client, mode: Mode, controller: Controller) -> Command {
        // postfix bushu
        guard let client = client as? ContextClient else {
            Log.i("★★Can't happen: PostfixBushuAction: client is not ContextClient")
            return .processed
        }
        let context = client.getYomi(1, 10, yomiCharacters: UserConfigs.shared.mazegaki.mazegakiYomiCharacters)
        if context.string.count < 1 {
            Log.i("Mazegaki henkan: no input")
            return .processed
        }
        let text = context.string
        let mazegaki = Mazegaki(context, inflection: inflection)
        if context.fromSelection {
            Log.i("Mazegaki: Offline from selection \(text)")
        } else {
            Log.i("Mazegaki: from \(text)")
        }

        let hits = mazegaki.find()
        if hits.isEmpty {
            return .processed
        }
        if !inflection && hits.count == 1 && hits[0].candidates().count == 1 {
            if mazegaki.submit(hit: hits[0], index: 0, client: client, controller: controller) {
                return .processed
            }
        }
        let newMode = MazegakiSelectionMode(controller: controller, mazegaki: mazegaki, hits: hits)
        controller.pushMode(newMode)
        newMode.showWindow()
        // Log.i("Mazegaki: more than one candidates")

        return .processed
    }
}
