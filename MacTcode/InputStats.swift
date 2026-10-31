import Foundation

/// しきい値ごとのストリーム統計を管理するクラス
class StreamCounter {
    /// 現在カウント中のストリーム長（文字数）
    var currentLength: Int = 0
    /// ストリーム長さのヒストグラム（要素数51、インデックス0..50）
    var histogram: [Int] = Array(repeating: 0, count: 51)

    /// ストリームに文字を追加する
    /// - Parameters:
    ///   - count: 追加する文字数
    ///   - subtract: 減算する文字数（ヨミ分の除外など）
    func addChars(_ count: Int, subtract: Int = 0) {
        let net = count - subtract
        if net > 0 {
            currentLength += net
        } else if net < 0 {
            // 理論的には発生しないが予防的に
            currentLength = max(0, currentLength + net)
        }
        // net == 0 は何もしない
    }

    /// 現在のストリームを終了してヒストグラムを更新する
    func endStream() {
        guard currentLength > 0 else { return }
        let idx = min(currentLength, 50)
        // Log.i("★Stream ended with length \(currentLength), updating histogram at index \(idx)")
        histogram[idx] += 1
        currentLength = 0
    }

    /// カウンタをリセットする
    func reset() {
        currentLength = 0
        histogram = Array(repeating: 0, count: 51)
    }
}

/// 入力統計情報を管理するシングルトンクラス
class InputStats {
    static let i = InputStats()

    struct KanjiConversionDelta: Equatable {
        let consumed: Int
        let introduced: Int
    }

    private var lastSyncDate = Date()
    /// nil のときはユーザー設定ディレクトリを使用する。テストでは専用ディレクトリを注入する。
    private let statisticsDirectoryURL: URL?

    private var basicCount = 0
    private var bushuCount = 0
    private var mazegakiCount = 0
    private var functionCount = 0
    private var totalActionCount = 0

    // 漢字変換統計（tc-record.txt の区間レコードにのみ保存する）
    // すべて非負の単調増加カウンタ。直接入力の純増減は解析側で算出する。
    private var directKanjiInputCount = 0
    private var consumedKanjiCount = 0
    private var bushuKanjiOutputCount = 0
    private var mazegakiKanjiOutputCount = 0

    // ストローク統計 (T-Code基本キーのみ)
    // per-key count (0..39)
    private var keyCount: [Int] = Array(repeating: 0, count: nKeys)
    // basic character frequency (1st*40 + 2nd -> 0..1599)
    private var basicCharCount: [Int] = Array(repeating: 0, count: nKeys * nKeys)
    // bigram (same shape as basicCharCount)
    private var bigramCount: [Int] = Array(repeating: 0, count: nKeys * nKeys)
    // panes frequency: "RL","RR","LL","LR"
    private var panes: [String: Int] = ["RL": 0, "RR": 0, "LL": 0, "LR": 0]
    // alternation counts
    private var alternation: [String: Int] = ["alternate": 0, "consecutive": 0, "first": 0]

    // state for continuity
    private var lastStrokeKey: Int? = nil
    private var lastStrokePane: String? = nil // "L" or "R"

    // ストリーム統計
    // 最後に確定した時刻（全しきい値で共有）
    private var lastKakuteiDate: Date? = nil
    // しきい値文字列 -> StreamCounter
    private var streamCounters: [String: StreamCounter] = [:]

    private let queue = DispatchQueue(label: "jp.mad-p.inputmethods.MacTcode.inputstats", attributes: .concurrent)

    init(statisticsDirectoryURL: URL? = nil) {
        self.statisticsDirectoryURL = statisticsDirectoryURL
        // 初期化時に保存済みの stroke-stats.json を読み込む
        loadStrokeStatsMaybe()
        // ストリームカウンタを初期化
        initStreamCounters()
    }

    /// 設定のしきい値に基づいてストリームカウンタを初期化する
    private func initStreamCounters() {
        let thresholds = UserConfigs.i.system.streamThresholds
        for key in thresholds {
            if streamCounters[key] == nil {
                streamCounters[key] = StreamCounter()
            }
        }
    }

    /// 基本文字入力のカウントを増やす
    func incrementBasicCount() {
        queue.async(flags: .barrier) {
            self.basicCount += 1
            self.totalActionCount += 1
            // Log.i("basicCount = \(self.basicCount)")
        }
    }

    /// T-Code の基本入力で出力した漢字を記録する。
    func recordDirectKanji(in string: String) {
        let count = Self.kanjiCount(in: string)
        guard count > 0 else { return }
        queue.async(flags: .barrier) {
            self.directKanjiInputCount += count
        }
    }

    /// 部首変換による、変換元漢字の消費と結果漢字の出力を記録する。
    func recordBushuKanjiConversion(source: String, result: String) {
        let consumed = Self.kanjiCount(in: source)
        let output = Self.kanjiCount(in: result)
        guard consumed > 0 || output > 0 else { return }
        queue.async(flags: .barrier) {
            self.consumedKanjiCount += consumed
            self.bushuKanjiOutputCount += output
        }
    }

    /// 交ぜ書き変換による漢字の差分を記録する。
    /// 変換前後で同じ文字として残った漢字は、消費・新規出力のどちらにも数えない。
    func recordMazegakiKanjiConversion(source: String, result: String) {
        let delta = Self.kanjiConversionDelta(from: source, to: result)
        guard delta.consumed > 0 || delta.introduced > 0 else { return }
        queue.async(flags: .barrier) {
            self.consumedKanjiCount += delta.consumed
            self.mazegakiKanjiOutputCount += delta.introduced
        }
    }

    /// テスト用に漢字変換統計の区間カウンタをリセットする。
    func resetKanjiConversionStats() {
        queue.sync(flags: .barrier) {
            self.directKanjiInputCount = 0
            self.consumedKanjiCount = 0
            self.bushuKanjiOutputCount = 0
            self.mazegakiKanjiOutputCount = 0
        }
    }

    /// 交ぜ書き変換前後の文字列から、消費・新規出力された漢字数を求める。
    /// 文字単位の最長共通部分列を使い、位置ずれした不変漢字も維持されたものとして扱う。
    static func kanjiConversionDelta(from source: String, to result: String) -> KanjiConversionDelta {
        let sourceCharacters = Array(source)
        let resultCharacters = Array(result)
        let sourceCount = sourceCharacters.count
        let resultCount = resultCharacters.count
        var lcs = Array(repeating: Array(repeating: 0, count: resultCount + 1), count: sourceCount + 1)

        if sourceCount > 0 && resultCount > 0 {
            for sourceIndex in 1...sourceCount {
                for resultIndex in 1...resultCount {
                    if sourceCharacters[sourceIndex - 1] == resultCharacters[resultIndex - 1] {
                        lcs[sourceIndex][resultIndex] = lcs[sourceIndex - 1][resultIndex - 1] + 1
                    } else {
                        lcs[sourceIndex][resultIndex] = max(lcs[sourceIndex - 1][resultIndex], lcs[sourceIndex][resultIndex - 1])
                    }
                }
            }
        }

        var preservedSourceKanji = 0
        var preservedResultKanji = 0
        var sourceIndex = sourceCount
        var resultIndex = resultCount
        while sourceIndex > 0 && resultIndex > 0 {
            if sourceCharacters[sourceIndex - 1] == resultCharacters[resultIndex - 1] {
                if Self.isKanji(sourceCharacters[sourceIndex - 1]) {
                    preservedSourceKanji += 1
                    preservedResultKanji += 1
                }
                sourceIndex -= 1
                resultIndex -= 1
            } else if lcs[sourceIndex - 1][resultIndex] >= lcs[sourceIndex][resultIndex - 1] {
                sourceIndex -= 1
            } else {
                resultIndex -= 1
            }
        }

        return KanjiConversionDelta(
            consumed: Self.kanjiCount(in: source) - preservedSourceKanji,
            introduced: Self.kanjiCount(in: result) - preservedResultKanji
        )
    }

    private static func kanjiCount(in string: String) -> Int {
        string.reduce(into: 0) { count, character in
            if isKanji(character) { count += 1 }
        }
    }

    private static func isKanji(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0x20000...0x2EBEF, 0x30000...0x323AF:
                return true
            default:
                return false
            }
        }
    }

    /// 部首変換のカウントを増やす
    func incrementBushuCount() {
        queue.async(flags: .barrier) {
            self.bushuCount += 1
            // バイグラム連続性を断つ（ストリームはrecordKakuteiで管理）
            self.recordNonStrokeEvent()
        }
    }

    /// 交ぜ書き変換のカウントを増やす
    func incrementMazegakiCount() {
        queue.async(flags: .barrier) {
            self.mazegakiCount += 1
            // バイグラム連続性を断つ（ストリームはrecordKakuteiで管理）
            self.recordNonStrokeEvent()
        }
    }

    /// 機能実行のカウントを増やす
    func incrementFunctionCount() {
        queue.async(flags: .barrier) {
            self.functionCount += 1
            self.totalActionCount += 1
            // バイグラム・ストリーム両方の連続性を断つ
            self.recordNonStrokeEvent()
            self.recordStreamEndEvent()
        }
    }

    // MARK: - Stroke statistics API

    /// ストローク（T-Code基本文字）を記録する
    /// - Parameter key1, key2: 0..(nKeys-1)
    func recordBasicStroke(key1: Int, key2: Int) {
        guard UserConfigs.i.system.strokeStatsEnabled else { return }
        guard (0..<nKeys).contains(key1) else { return }
        guard (0..<nKeys).contains(key2) else { return }
        queue.async(flags: .barrier) {
            let idx = key1 * nKeys + key2
            self.basicCharCount[idx] += 1
            let pane1 = key1 % 10 < 5 ? "L" : "R"
            let pane2 = key2 % 10 < 5 ? "L" : "R"
            let pair = pane1 + pane2
            if self.panes[pair] != nil {
                self.panes[pair]! += 1
            }
        }
    }

    /// ストローク（T-Code基本キー）を記録する
    /// - Parameter key: 0..(nKeys-1)
    func recordStroke(key: Int) {
        guard UserConfigs.i.system.strokeStatsEnabled else { return }
        guard (0..<nKeys).contains(key) else { return }
        queue.async(flags: .barrier) {
            self.keyCount[key] += 1
            // panes
            let pane = (key % 10) < 5 ? "L" : "R"
            if let last = self.lastStrokeKey {
                // bigram
                let idx = last * nKeys + key
                self.bigramCount[idx] += 1
                // panes pair
                if let lastPane = self.lastStrokePane {
                    // alternation
                    if lastPane == pane {
                        self.alternation["consecutive"]! += 1
                    } else {
                        self.alternation["alternate"]! += 1
                    }
                }
            } else {
                // first hit
                self.alternation["first"]! += 1
            }
            // update last
            self.lastStrokeKey = key
            self.lastStrokePane = pane
        }
    }

    /// 非ストロークイベントを記録して連続性を断つ（バイグラム統計のみ）
    func recordNonStrokeEvent() {
        // Log.i("recordNonStrokeEvent called")
        guard UserConfigs.i.system.strokeStatsEnabled else { return }
        queue.async(flags: .barrier) {
            self.recordNonStrokeEventInternal()
        }
    }

    // internal: assumes barrier queue（バイグラム統計のみ）
    private func recordNonStrokeEventInternal() {
        self.lastStrokeKey = nil
        self.lastStrokePane = nil
    }

    /// ストリーム統計の不連続を記録する（ストリームを終了させる）
    func recordStreamEndEvent() {
        // Log.i("recordStreamEndEvent called")
        guard UserConfigs.i.system.streamStatsEnabled else { return }
        queue.async(flags: .barrier) {
            self.recordStreamEndEventInternal()
        }
    }

    // internal: assumes barrier queue
    private func recordStreamEndEventInternal() {
        for counter in self.streamCounters.values {
            counter.endStream()
        }
        self.lastKakuteiDate = nil
    }

    /// 漢直入力の確定を記録する（ストリーム統計用）
    /// - Parameters:
    ///   - charCount: 確定された文字数
    ///   - subtract: 減算する文字数（ヨミ分など。Bushuでは2、Mazegakiではhit.length）
    func recordKakutei(charCount: Int, subtract: Int = 0) {
        // Log.i("recordKakutei called: charCount = \(charCount), subtract = \(subtract)")
        guard UserConfigs.i.system.streamStatsEnabled else { return }
        queue.async(flags: .barrier) {
            let now = Date()
            if let last = self.lastKakuteiDate {
                let elapsed = now.timeIntervalSince(last)
                for (key, counter) in self.streamCounters {
                    guard let threshold = Double(key) else { continue }
                    if elapsed >= threshold {
                        // Log.i("Stream threshold \(threshold) exceeded (elapsed = \(elapsed)), ending stream")
                        counter.endStream()
                    }
                    counter.addChars(charCount, subtract: subtract)
                }
            } else {
                for counter in self.streamCounters.values {
                    counter.addChars(charCount, subtract: subtract)
                }
            }
            self.lastKakuteiDate = now
        }
    }

    /// ストローク統計をリセット（メモリ内）
    func resetStrokeStats() {
        queue.async(flags: .barrier) {
            self.keyCount = Array(repeating: 0, count: nKeys)
            self.basicCharCount = Array(repeating: 0, count: nKeys * nKeys)
            self.bigramCount = Array(repeating: 0, count: nKeys * nKeys)
            self.panes = ["RL": 0, "RR": 0, "LL": 0, "LR": 0]
            self.alternation = ["alternate": 0, "consecutive": 0, "first": 0]
            self.lastStrokeKey = nil
            self.lastStrokePane = nil
            // ストリーム統計もリセット
            for counter in self.streamCounters.values { counter.reset() }
            self.lastKakuteiDate = nil
        }
    }

    // MARK: - Persistence (JSON)

    private func strokeStatsFileURL() -> URL {
        statisticsFileURL(named: "stroke-stats.json")
    }

    private func statisticsFileURL(named filename: String) -> URL {
        (statisticsDirectoryURL ?? UserConfigs.i.macTcodeURL).appendingPathComponent(filename)
    }

    func loadStrokeStatsMaybe() {
        guard UserConfigs.i.system.strokeStatsEnabled else { return }
        let fileURL = strokeStatsFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        queue.async(flags: .barrier) {
            do {
                let data = try Data(contentsOf: fileURL)
                if let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let k = obj["keyCount"] as? [Int], k.count == nKeys { self.keyCount = k }
                    if let b = obj["basicCharCount"] as? [Int], b.count == nKeys * nKeys { self.basicCharCount = b }
                    if let bg = obj["bigram"] as? [Int], bg.count == nKeys * nKeys { self.bigramCount = bg }
                    if let p = obj["panes"] as? [String: Int] { self.panes = p }
                    if let a = obj["alternation"] as? [String: Int] { self.alternation = a }
                    // ストリーム統計を読み込む
                    if let sc = obj["streamCount"] as? [String: [Int]] {
                        for (key, hist) in sc {
                            if hist.count == 51 {
                                let counter = self.streamCounters[key] ?? StreamCounter()
                                counter.histogram = hist
                                self.streamCounters[key] = counter
                            }
                        }
                    }
                }
            } catch {
                Log.i("Failed to load stroke-stats: \(error)")
            }
        }
    }

    func writeStrokeStatsToFile() {
        guard UserConfigs.i.system.strokeStatsEnabled else { return }
        queue.sync {
            let fileURL = strokeStatsFileURL()
            var obj: [String: Any] = [:]
            obj["keyCount"] = self.keyCount
            obj["basicCharCount"] = self.basicCharCount
            obj["bigram"] = self.bigramCount
            obj["panes"] = self.panes
            obj["alternation"] = self.alternation
            obj["lastUpdated"] = ISO8601DateFormatter().string(from: Date())
            // ストリーム統計を書き出す（現在進行中のストリームは反映しない）
            if UserConfigs.i.system.streamStatsEnabled {
                var streamCount: [String: [Int]] = [:]
                for (key, counter) in self.streamCounters {
                    streamCount[key] = counter.histogram
                }
                obj["streamCount"] = streamCount
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: fileURL)
            } catch {
                Log.i("Failed to write stroke-stats: \(error)")
            }
            Log.i("★Stroke statistics written")
        }
    }

    public func writeStatsToFileMaybe() {
        let systemConfig = UserConfigs.i.system
        let interval = systemConfig.syncStatsInterval
        Log.i("interval = \(interval), since last sync = \(Date().timeIntervalSince(lastSyncDate))")
        if interval > 0 {
            if Date().timeIntervalSince(lastSyncDate) > Double(interval) {
                writeStatsToFile()
            }
        }
    }
    /// 統計情報をファイルに書き出す
    public func writeStatsToFile(force: Bool = false) {
        queue.sync {
            // 学習データも同じタイミングで保存
            MazegakiDict.i.saveMruData()
            Bushu.i.saveAutoData()

            let hasKanjiConversionStats = directKanjiInputCount > 0 ||
                consumedKanjiCount > 0 ||
                bushuKanjiOutputCount > 0 ||
                mazegakiKanjiOutputCount > 0
            guard totalActionCount > 0 || hasKanjiConversionStats else {
                lastSyncDate = Date()
                return
            }
            // If not forced, obey syncStatsInterval; if forced (manual/menu/signal), allow write even when interval == 0
            if !force {
                guard UserConfigs.i.system.syncStatsInterval > 0 else {
                    return
                }
            }

            let fileManager = FileManager.default
            let fileURL = self.statisticsFileURL(named: "tc-record.txt")

            // 現在の日時を取得
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.locale = Locale.current
            dateFormatter.timeZone = TimeZone.current
            let dateString = dateFormatter.string(from: Date())

            // パーセント計算
            let bushuPercent = totalActionCount > 0 ? (bushuCount * 100) / totalActionCount : 0
            let mazegakiPercent = totalActionCount > 0 ? (mazegakiCount * 100) / totalActionCount : 0
            let functionPercent = totalActionCount > 0 ? (functionCount * 100) / totalActionCount : 0

            // 統計行を作成
            let statsLine = String(format: "%@ 文字: %4d  部首: %3d(%d%%)  交ぜ書き: %3d(%d%%)  機能: %3d(%d%%)  kanjiDirect=%d kanjiConsumed=%d kanjiBushu=%d kanjiMazegaki=%d\n",
                                   dateString,
                                   basicCount,
                                   bushuCount, bushuPercent,
                                   mazegakiCount, mazegakiPercent,
                                   functionCount, functionPercent,
                                   directKanjiInputCount,
                                   consumedKanjiCount,
                                   bushuKanjiOutputCount,
                                   mazegakiKanjiOutputCount)

            // ファイルに追記
            if let data = statsLine.data(using: .utf8) {
                if fileManager.fileExists(atPath: fileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        try? fileHandle.close()
                    }
                } else {
                    try? data.write(to: fileURL)
                }
            }

            // 同期タイミングでstroke-statsも書き出す（累積）
            self.writeStrokeStatsToFile()

            Log.i("★Statistics written: \(statsLine.trimmingCharacters(in: .whitespacesAndNewlines))")
            lastSyncDate = Date()
            basicCount = 0
            bushuCount = 0
            mazegakiCount = 0
            functionCount = 0
            totalActionCount = 0
            directKanjiInputCount = 0
            consumedKanjiCount = 0
            bushuKanjiOutputCount = 0
            mazegakiKanjiOutputCount = 0
        }
    }
}
