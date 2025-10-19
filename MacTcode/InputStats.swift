import Foundation

/// 入力統計情報を管理するシングルトンクラス
class InputStats {
    static let shared = InputStats()

    private var basicCount = 0
    private var bushuCount = 0
    private var mazegakiCount = 0
    private var functionCount = 0
    private var totalActionCount = 0

    private let queue = DispatchQueue(label: "com.mactcode.inputstats", attributes: .concurrent)

    private init() {
        setupSignalHandlers()
    }

    /// 基本文字入力のカウントを増やす
    func incrementBasicCount() {
        queue.async(flags: .barrier) {
            self.basicCount += 1
            self.totalActionCount += 1
        }
    }

    /// 部首変換のカウントを増やす
    func incrementBushuCount() {
        queue.async(flags: .barrier) {
            self.bushuCount += 1
        }
    }

    /// 交ぜ書き変換のカウントを増やす
    func incrementMazegakiCount() {
        queue.async(flags: .barrier) {
            self.mazegakiCount += 1
        }
    }

    /// 機能実行のカウントを増やす
    func incrementFunctionCount() {
        queue.async(flags: .barrier) {
            self.functionCount += 1
            self.totalActionCount += 1
        }
    }

    /// 統計情報をファイルに書き出す
    private func writeStatsToFile() {
        queue.sync {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let macTcodeURL = appSupportURL.appendingPathComponent("MacTcode")

            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: macTcodeURL.path) {
                try? fileManager.createDirectory(at: macTcodeURL, withIntermediateDirectories: true)
            }

            let fileURL = macTcodeURL.appendingPathComponent("tc-record")

            // 現在の日時を取得
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            dateFormatter.locale = Locale(identifier: "ja_JP")
            let dateString = dateFormatter.string(from: Date())

            // パーセント計算
            let bushuPercent = totalActionCount > 0 ? (bushuCount * 100) / totalActionCount : 0
            let mazegakiPercent = totalActionCount > 0 ? (mazegakiCount * 100) / totalActionCount : 0
            let functionPercent = totalActionCount > 0 ? (functionCount * 100) / totalActionCount : 0

            // 統計行を作成
            let statsLine = String(format: "%@ 文字: %4d  部首: %4d(%d%%)  交ぜ書き: %4d(%d%%)  機能: %4d(%d%%)\n",
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

            Log.i("★Statistics written: \(statsLine.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    /// シグナルハンドラを設定
    private func setupSignalHandlers() {
        // SIG_IGNでデフォルトハンドリングを無視
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        // SIGINT用のDispatchSourceを作成
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSource.setEventHandler { [weak self] in
            Log.i("★Received SIGINT, writing statistics...")
            self?.writeStatsToFile()
            exit(0)
        }
        sigintSource.resume()

        // SIGTERM用のDispatchSourceを作成
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigtermSource.setEventHandler { [weak self] in
            Log.i("★Received SIGTERM, writing statistics...")
            self?.writeStatsToFile()
            exit(0)
        }
        sigtermSource.resume()
    }
}
