import Foundation

var termPipe: [Int32] = [-1, -1]

/// 入力統計情報を管理するシングルトンクラス
class InputStats {
    static let shared = InputStats()

    private var basicCount = 0
    private var bushuCount = 0
    private var mazegakiCount = 0
    private var functionCount = 0
    private var totalActionCount = 0

    private let queue = DispatchQueue(label: "jp.mad-p.inputmethods.MacTcode.inputstats", attributes: .concurrent)

    private init() {
        InputStats.setupSignalHandlers()
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
    public func writeStatsToFile() {
        queue.sync {
            guard totalActionCount > 0 else {
                return
            }
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let macTcodeURL = appSupportURL.appendingPathComponent("MacTcode")

            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: macTcodeURL.path) {
                try? fileManager.createDirectory(at: macTcodeURL, withIntermediateDirectories: true)
            }

            let fileURL = macTcodeURL.appendingPathComponent("tc-record.txt")

            // 現在の日時を取得
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
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

            Log.i("★Statistics written: \(statsLine.trimmingCharacters(in: .whitespacesAndNewlines))")
            basicCount = 0
            bushuCount = 0
            mazegakiCount = 0
            functionCount = 0
            totalActionCount = 0
        }
    }

    
    /// シグナルハンドラを設定
    static func setupSignalHandlers() {
        // パイプ（[読端, 書端]）
        guard pipe(&termPipe) == 0 else { fatalError("pipe failed") }
        
        // C呼出規約、キャプチャなし
        let sigtermHandler: @convention(c) (Int32) -> Void = { _ in
            var one: UInt8 = 1
            // write は async-signal-safe
            _ = withUnsafePointer(to: &one) {
                $0.withMemoryRebound(to: UInt8.self, capacity: 1) {
                    write(termPipe[1], $0, 1)
                }
            }
        }
        
        // シグナル登録
        signal(SIGINT, sigtermHandler)
        signal(SIGTERM, sigtermHandler)
        
        // SIGINT用のDispatchSourceを作成
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSource.setEventHandler {
            Log.i("★Received SIGINT, writing statistics...")
            shared.writeStatsToFile()
            exit(0)
        }
        sigintSource.resume()
        
        // SIGTERM用のDispatchSourceを作成
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigtermSource.setEventHandler {
            Log.i("★Received SIGTERM, writing statistics...")
            shared.writeStatsToFile()
            exit(0)
        }
        sigtermSource.resume()
    }
}
