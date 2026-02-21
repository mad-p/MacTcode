import Foundation

/// 入力統計情報を管理するシングルトンクラス
class InputStats {
    static let i = InputStats()
    
    private var lastSyncDate = Date()

    private var basicCount = 0
    private var bushuCount = 0
    private var mazegakiCount = 0
    private var functionCount = 0
    private var totalActionCount = 0

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

    private let queue = DispatchQueue(label: "jp.mad-p.inputmethods.MacTcode.inputstats", attributes: .concurrent)

    private init() {
        // 初期化時に保存済みの stroke-stats.json を読み込む
        loadStrokeStatsMaybe()
    }

    /// 基本文字入力のカウントを増やす
    func incrementBasicCount() {
        queue.async(flags: .barrier) {
            self.basicCount += 1
            self.totalActionCount += 1
            Log.i("basicCount = \(self.basicCount)")
        }
    }

    /// 部首変換のカウントを増やす
    func incrementBushuCount() {
        queue.async(flags: .barrier) {
            self.bushuCount += 1
            // continuity break
            self.recordNonStrokeEventInternal()
        }
    }

    /// 交ぜ書き変換のカウントを増やす
    func incrementMazegakiCount() {
        queue.async(flags: .barrier) {
            self.mazegakiCount += 1
            // continuity break
            self.recordNonStrokeEventInternal()
        }
    }

    /// 機能実行のカウントを増やす
    func incrementFunctionCount() {
        queue.async(flags: .barrier) {
            self.functionCount += 1
            self.totalActionCount += 1
            // continuity break
            self.recordNonStrokeEventInternal()
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

    /// 非ストロークイベントを記録して連続性を断つ
    func recordNonStrokeEvent() {
        guard UserConfigs.i.system.strokeStatsEnabled else { return }
        queue.async(flags: .barrier) {
            self.recordNonStrokeEventInternal()
        }
    }

    // internal: assumes barrier queue
    private func recordNonStrokeEventInternal() {
        self.lastStrokeKey = nil
        self.lastStrokePane = nil
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
        }
    }

    // MARK: - Persistence (JSON)

    private func strokeStatsFileURL() -> URL {
        return UserConfigs.i.configFileURL("stroke-stats.json")
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
    public func writeStatsToFile() {
        queue.sync {
            // 学習データも同じタイミングで保存
            MazegakiDict.i.saveMruData()
            Bushu.i.saveAutoData()

            guard totalActionCount > 0 else {
                lastSyncDate = Date()
                return
            }
            guard UserConfigs.i.system.syncStatsInterval > 0 else {
                return
            }
            
            let fileManager = FileManager.default
            let fileURL = UserConfigs.i.configFileURL("tc-record.txt")

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
            let statsLine = String(format: "%@ 文字: %4d  部首: %3d(%d%%)  交ぜ書き: %3d(%d%%)  機能: %3d(%d%%)\n",
                                 dateString,
                                 basicCount,
                                 bushuCount, bushuPercent,
                                 mazegakiCount, mazegakiPercent,
                                 functionCount, functionPercent)

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
        }
    }
}
