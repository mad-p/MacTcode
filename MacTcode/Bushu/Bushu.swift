//
//  TcodeBushu.swift
//  MacTcode
//
//  Created by maeda on 2024/05/27.
//

// 部首変換アルゴリズム
// tc-bushu.el の初期バージョンのアルゴリズムを再現。
// 元コードはGPLだが、コードコピーはしていないので、MITライセンスで配布できるはず。

import Foundation

final class Bushu {
    static let i = Bushu()

    private var composeTable: [[String]: String] = [:]
    private var decomposeTable: [String: [String]] = [:]
    private var equivTable: [String: String] = [:]
    var autoDict: [String: String] = [:]  // 自動部首変換学習データ（キー: 合成元2文字、値: 合成結果1文字）
    var toSyncAutoDict = false

    func readDictionary() {
        Log.i("Read bushu dictionary...")
        composeTable = [:]
        decomposeTable = [:]
        equivTable = [:]
        let dictionaryFile = UserConfigs.shared.bushu.dictionaryFile
        if let bushuDic = UserConfigs.shared.loadConfig(file: dictionaryFile) {
            for line in bushuDic.components(separatedBy: .newlines) {
                let chars = line.map {String($0)}
                if chars.count == 3 {
                    if chars[0] == "N" {
                        equivTable[chars[2]] = chars[1]
                    } else {
                        let pair = [chars[0], chars[1]]
                        decomposeTable[chars[2]] = pair
                        composeTable[pair] = chars[2]
                    }
                } else {
                    if line.count > 0 {
                        Log.i("Invalid bushu.dic entry: \(line)")
                    }
                }
            }
        }
        Log.i("\(composeTable.count) bushu entries read")
    }

    private init() {
        readDictionary()

        // 自動学習データを読み込む
        if UserConfigs.shared.bushu.autoEnabled {
            loadAutoData()
        }
    }

    func basicCompose(char1: String, char2: String) -> String? {
        return (composeTable[[char1, char2]] ??
                composeTable[[char2, char1]])
    }

    func compose(char1: String, char2: String) -> String? {
        if let ch = basicCompose(char1: char1, char2: char2) {
            return ch
        }
        let ch1 = equivTable[char1] ?? char1
        let ch2 = equivTable[char2] ?? char2
        if ((ch1 != char1) || (ch2 != char2)) {
            if let ch = basicCompose(char1: ch1, char2: ch2) {
                return ch
            }
        }
        let tc1 = decomposeTable[ch1]
        let tc2 = decomposeTable[ch2]
        let tc11 = tc1?[0]
        let tc12 = tc1?[1]
        let tc21 = tc2?[0]
        let tc22 = tc2?[1]
        // subtraction
        if (tc11 == ch2) && (tc12 != ch1) && (tc12 != ch2) {
            return tc12
        }
        if (tc12 == ch2) && (tc11 != ch1) && (tc11 != ch2) {
            return tc11
        }
        if (tc21 == ch1) && (tc22 != ch1) && (tc22 != ch2) {
            return tc22
        }
        if (tc22 == ch1) && (tc21 != ch1) && (tc21 != ch2) {
            return tc21
        }
        // parts-wise composition
        for pair in [[ch1, tc22], [ch2, tc11], [ch1, tc21], [ch2, tc12],
                     [tc12, tc22], [tc21, tc12], [tc11, tc22], [tc21, tc11]] {
            let p1 = pair[0]
            let p2 = pair[1]
            if p1 != nil && p2 != nil {
                if let ch = basicCompose(char1: p1!, char2: p2!) {
                    if (ch != ch1) && (ch != ch2) {
                        return ch
                    }
                }
            }
        }
        // new subtraction
        if (tc11 != nil) && (tc11 == tc21) && (tc12 != ch1) && (tc12 != ch2) {
            return tc12
        }
        if (tc11 != nil) && (tc11 == tc22) && (tc12 != ch1) && (tc12 != ch2) {
            return tc12
        }
        if (tc12 != nil) && (tc12 == tc21) && (tc11 != ch1) && (tc11 != ch2) {
            return tc11
        }
        if (tc12 != nil) && (tc12 == tc22) && (tc11 != ch1) && (tc11 != ch2) {
            return tc11
        }
        // not found
        return nil
    }

    /// 自動学習データを読み込む
    func loadAutoData() {
        Log.i("Load bushu auto data...")
        autoDict = [:]
        let autoFile = UserConfigs.shared.bushu.autoFile
        if let autoData = UserConfigs.shared.loadConfig(file: autoFile) {
            for line in autoData.components(separatedBy: .newlines) {
                let chars = line.map { String($0) }
                if chars.count == 3 {
                    // 合成元2文字をキーとして、合成結果1文字を値とする
                    let key = chars[0] + chars[1]
                    autoDict[key] = chars[2]
                } else {
                    if line.count > 0 {
                        Log.i("Invalid \(autoFile) line: \(line)")
                    }
                }
            }
        }
        toSyncAutoDict = false
        Log.i("\(autoDict.count) bushu auto entries loaded")
    }

    /// 自動学習データを保存する
    func saveAutoData() {
        guard UserConfigs.shared.bushu.autoEnabled else {
            return
        }
        guard toSyncAutoDict else {
            Log.i("Bushu.autoDict is clean. Nothing to save")
            return
        }

        Log.i("Save bushu auto data...")
        let autoFile = UserConfigs.shared.bushu.autoFile
        var lines: [String] = []
        for (key, value) in autoDict.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key)\(value)")
        }
        let content = lines.joined(separator: "\n")

        do {
            let url = UserConfigs.shared.configFileURL(autoFile)
            try content.write(to: url, atomically: true, encoding: .utf8)
            Log.i("Bushu auto data saved: \(autoDict.count) entries to \(url.path)")
            toSyncAutoDict = false
        } catch {
            Log.i("Failed to save bushu auto data: \(error)")
        }
    }

    /// 受容された部首変換結果を学習データに追加する
    /// - Parameters:
    ///   - source1: 合成元の1文字目
    ///   - source2: 合成元の2文字目
    ///   - result: 合成結果
    func updateAutoEntry(source1: String, source2: String, result: String) {
        guard UserConfigs.shared.bushu.autoEnabled else {
            return
        }

        // 合成元の2文字をキーとして保存（順序を保持）
        let key = source1 + source2

        // 既存の値が禁止設定("N")の場合は上書きしない
        if let existingValue = autoDict[key], existingValue == "N" {
            Log.i("updateAutoEntry: '\(key)' is disabled, not updating")
            return
        }

        if autoDict[key] != result {
            autoDict[key] = result
            Log.i("updateAutoEntry: '\(key)' -> '\(result)'")
            toSyncAutoDict = true
        }
    }

    /// 自動部首変換を禁止する設定を追加
    /// - Parameters:
    ///   - source1: 合成元の1文字目
    ///   - source2: 合成元の2文字目
    func disableAutoEntry(source1: String, source2: String) {
        guard UserConfigs.shared.bushu.autoEnabled else {
            return
        }

        let key = source1 + source2
        let currentValue = autoDict[key]

        // 既に禁止設定の場合は何もしない
        if currentValue == "N" {
            Log.i("disableAutoEntry: '\(key)' is already disabled")
            return
        }

        autoDict[key] = "N"
        Log.i("disableAutoEntry: '\(key)' -> 'N'")
        toSyncAutoDict = true
    }

    /// 禁止設定を解除する（値を削除するのみ、自動設定の追加は通常の受容処理で行う）
    /// - Parameters:
    ///   - source1: 合成元の1文字目
    ///   - source2: 合成元の2文字目
    func enableAutoEntry(source1: String, source2: String) {
        guard UserConfigs.shared.bushu.autoEnabled else {
            return
        }

        let key = source1 + source2

        // 禁止設定の場合のみ解除
        if let currentValue = autoDict[key], currentValue == "N" {
            autoDict.removeValue(forKey: key)
            Log.i("enableAutoEntry: '\(key)' removed from disabled list")
            toSyncAutoDict = true
        }
    }
    
    // 部首変換後の PendingKakutei で受容された場合、あるいは禁止設定コマンドが入力されたときの処理
    func onAccept(_ parameter: Any?, _ inputEvent: InputEvent?) -> HandleResult {
        // 受容時の処理: 自動学習データを更新
        Log.i("Bushu.onAccept: parameter=\(String(describing: parameter)), inputEvent=\(String(describing: inputEvent))")
        guard let param = parameter as? [String] else { return .forward }
        let src1 = param[0]
        let src2 = param[1]
        let res = param[2]
        
        // inputEventをチェック
        if let event = inputEvent, event.type == .printable, let text = event.text {
            let disableKeys = UserConfigs.shared.bushu.disableAutoKeys
            let addKeys = UserConfigs.shared.bushu.addAutoKeys
            
            if disableKeys.contains(text) {
                // 禁止設定を追加
                Log.i("disable auto bushu: [\(src1), \(src2)]")
                Bushu.i.disableAutoEntry(source1: src1, source2: src2)
                return .processed
            } else if addKeys.contains(text) {
                // 禁止設定を解除してから自動設定を追加
                Log.i("enable and add auto bushu: [\(src1), \(src2), \(res)]")
                Bushu.i.enableAutoEntry(source1: src1, source2: src2)
                Bushu.i.updateAutoEntry(source1: src1, source2: src2, result: res)
                return .processed
            }
        }
        
        // 通常の受容処理
        Log.i("accepted bushu kakutei: parameter = [\(src1), \(src2), \(res)]")
        Bushu.i.updateAutoEntry(source1: src1, source2: src2, result: res)
        return .forward
    }

    /// 部首変換を実行してPendingKakuteiを生成する
    /// - Parameters:
    ///   - source1: 合成元の1文字目
    ///   - source2: 合成元の2文字目
    ///   - client: クライアント
    ///   - controller: コントローラ
    ///   - yomi: YomiContext
    /// - Returns: 変換が成功したかどうか
    func submit(source1: String, source2: String, client: Client, controller: Controller, yomi: YomiContext) -> Bool {
        guard let client = client as? ContextClient else {
            Log.i("★★Can't happen: Bushu.submit: client is not ContextClient")
            return false
        }

        guard let result = compose(char1: source1, char2: source2) else {
            return false
        }

        Log.i("Bushu \(source1)\(source2) -> \(result)")
        let backspaceCount = client.replaceYomi(result, length: 2, from: yomi)
        controller.setBackspaceIgnore(backspaceCount)
        InputStats.shared.incrementBushuCount()

        // 自動学習が有効な場合、PendingKakuteiを生成
        if UserConfigs.shared.bushu.autoEnabled {
            let yomiString = source1 + source2
            let pending = PendingKakuteiMode(
                yomi: yomiString,
                kakutei: result,
                onAccepted: { parameter, inputEvent in return self.onAccept(parameter, inputEvent) },
                parameter: [source1, source2, result]
            )
            controller.pushMode(pending)
        }

        return true
    }

    /// 自動部首変換を試みる
    /// - Parameters:
    ///   - client: クライアント
    ///   - controller: コントローラ
    /// - Returns: 自動変換が実行されたかどうか
    func tryAutoBushu(client: ContextClient!, controller: Controller) -> Bool {
        // 自動学習が無効な場合は何もしない
        guard UserConfigs.shared.bushu.autoEnabled else {
            return false
        }

        let recent = client.recent
        
        // 最後の2文字を取得できない場合は何もしない
        guard recent.text.count >= 2 else {
            return false
        }

        // 最後の2文字を取得
        let text = recent.text
        let startIndex = text.index(text.endIndex, offsetBy: -2)
        let src = String(text[startIndex...])

        // 学習データに該当エントリがあるかチェック
        guard let result = autoDict[src] else {
            return false
        }

        // 禁止設定チェック
        if result == "N" {
            Log.i("Auto bushu disabled for: \(src)")
            return false
        }

        Log.i("Auto bushu: \(src) -> \(result)")

        // YomiContextを作成
        let yomiContext = YomiContext(
            string: src,
            range: NSRange(location: recent.text.count - 2, length: 2),
            fromSelection: false,
            fromMirror: true
        )

        // 変換実行
        let backspaceCount = client.replaceYomi(result, length: 2, from: yomiContext)
        controller.setBackspaceIgnore(backspaceCount)

        // PendingKakuteiを作成
        let source1 = String(src.dropLast())
        let source2 = String(src.dropFirst())
        let pending = PendingKakuteiMode(
            yomi: src,
            kakutei: result,
            onAccepted: { parameter, inputEvent in return self.onAccept(parameter, inputEvent) },
            parameter: [source1, source2, result]
        )
        controller.pushMode(pending)
        
        return true
    }
}
