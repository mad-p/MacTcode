import XCTest
@testable import MacTcode

final class StrokeStatsTests: XCTestCase {
    private var statisticsDirectoryURL: URL!
    private var fileURL: URL!
    private var recordFileURL: URL!
    private var stats: InputStats!

    // 設定を上書きするヘルパー
    private func makeSystem(strokeStatsEnabled: Bool = true,
                            streamStatsEnabled: Bool = true,
                            streamThresholds: [String] = ["0.5", "1.0"]) -> UserConfigs.SystemConfig {
        let s = UserConfigs.i.system
        return UserConfigs.SystemConfig(
            recentTextMaxLength: s.recentTextMaxLength,
            excludedApplications: s.excludedApplications,
            disableOneYomiApplications: s.disableOneYomiApplications,
            dummyInsertTextApps: s.dummyInsertTextApps,
            logEnabled: s.logEnabled,
            keyboardLayout: s.keyboardLayout,
            keyboardLayoutMapping: s.keyboardLayoutMapping,
            syncStatsInterval: s.syncStatsInterval,
            cancelPeriod: s.cancelPeriod,
            strokeStatsEnabled: strokeStatsEnabled,
            streamStatsEnabled: streamStatsEnabled,
            streamThresholds: streamThresholds
        )
    }

    override func setUpWithError() throws {
        statisticsDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacTcode-StrokeStatsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: statisticsDirectoryURL, withIntermediateDirectories: true)
        fileURL = statisticsDirectoryURL.appendingPathComponent("stroke-stats.json")
        recordFileURL = statisticsDirectoryURL.appendingPathComponent("tc-record.txt")
        stats = InputStats(statisticsDirectoryURL: statisticsDirectoryURL)
        UserConfigs.i.updateSystem(makeSystem())
    }

    override func tearDownWithError() throws {
        UserConfigs.i.updateSystem(makeSystem())
        stats = nil
        try FileManager.default.removeItem(at: statisticsDirectoryURL)
        statisticsDirectoryURL = nil
    }

    func loadStats() throws -> [String: Any] {
        let data = try Data(contentsOf: fileURL)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else { throw NSError(domain: "Test", code: 1) }
        return dict
    }

    func testRecordStrokeAndBigram() throws {
        stats.resetStrokeStats()
        stats.recordStroke(key: 2)
        stats.recordStroke(key: 7)
        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let keyCount = dict["keyCount"] as? [Int] else { XCTFail("no keyCount"); return }
        guard let bigram = dict["bigram"] as? [Int] else { XCTFail("no bigram"); return }
        guard let alternation = dict["alternation"] as? [String: Int] else { XCTFail("no alternation"); return }

        XCTAssertEqual(1, keyCount[2])
        XCTAssertEqual(1, keyCount[7])
        let idx = 2 * 40 + 7
        XCTAssertEqual(1, bigram[idx])
        XCTAssertEqual(1, alternation["first"])
        XCTAssertEqual(1, alternation["alternate"])
    }

    func testContinuityBreak() throws {
        stats.resetStrokeStats()
        stats.recordStroke(key: 1)
        stats.recordNonStrokeEvent()
        stats.recordStroke(key: 3)
        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let bigram = dict["bigram"] as? [Int] else { XCTFail("no bigram"); return }
        let idx = 1 * 40 + 3
        XCTAssertEqual(0, bigram[idx])
        guard let alternation = dict["alternation"] as? [String: Int] else { XCTFail("no alternation"); return }
        XCTAssertEqual(2, alternation["first"])
    }

    func testDisabledDoesNotWrite() throws {
        UserConfigs.i.updateSystem(makeSystem(strokeStatsEnabled: false))
        stats.resetStrokeStats()
        stats.recordStroke(key: 5)
        stats.writeStrokeStatsToFile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - ストリーム統計テスト

    func testStreamSingleStream() throws {
        // 連続した3文字入力でストリーム長3が記録される
        stats.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        stats.recordKakutei(charCount: 1)
        stats.recordKakutei(charCount: 1)
        stats.recordKakutei(charCount: 1)
        // ストリーム終了
        stats.recordStreamEndEvent()
        let exp = expectation(description: "barrier queue flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let streamCount = dict["streamCount"] as? [String: [Int]] else {
            XCTFail("no streamCount"); return
        }
        guard let hist = streamCount["1.0"] else { XCTFail("no histogram for 1.0"); return }
        XCTAssertEqual(51, hist.count)
        XCTAssertEqual(1, hist[3], "ストリーム長3が1回記録されるべき")
    }

    func testStreamBreakByThreshold() throws {
        // しきい値0.5秒で: 連続2文字 → 0.6秒待機 → 連続1文字
        // 0.5秒しきい値では長さ2と長さ1の2ストリームになる
        // 1.0秒しきい値では長さ3の1ストリームになる
        stats.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["0.5", "1.0"]))
        stats.recordKakutei(charCount: 1)
        stats.recordKakutei(charCount: 1)

        // 0.6秒待機（0.5秒しきい値を超えるが1.0秒しきい値は超えない）
        let wait1 = expectation(description: "wait 0.6s")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.65) { wait1.fulfill() }
        wait(for: [wait1], timeout: 2.0)

        stats.recordKakutei(charCount: 1)

        // ストリーム終了
        stats.recordStreamEndEvent()
        let wait2 = expectation(description: "barrier flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { wait2.fulfill() }
        wait(for: [wait2], timeout: 1.0)

        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let streamCount = dict["streamCount"] as? [String: [Int]] else {
            XCTFail("no streamCount"); return
        }

        // 0.5秒しきい値: ストリーム長2(1回) + 長さ1(1回)
        guard let hist05 = streamCount["0.5"] else { XCTFail("no histogram for 0.5"); return }
        XCTAssertEqual(1, hist05[2], "0.5秒しきい値: 長さ2が1回")
        XCTAssertEqual(1, hist05[1], "0.5秒しきい値: 長さ1が1回")

        // 1.0秒しきい値: ストリーム長3(1回)
        guard let hist10 = streamCount["1.0"] else { XCTFail("no histogram for 1.0"); return }
        XCTAssertEqual(1, hist10[3], "1.0秒しきい値: 長さ3が1回")
    }

    func testStreamMazegakiCharCount() throws {
        // 交ぜ書き変換で3文字確定、ヨミ4文字減算 → net=-1 → currentLength変化なし
        // さらに基本文字1文字 → 合計1文字のストリーム
        stats.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        // ヨミ4文字打鍵済みとして subtract: 4、確定3文字
        stats.recordKakutei(charCount: 3, subtract: 4)
        stats.recordKakutei(charCount: 1)
        stats.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let streamCount = dict["streamCount"] as? [String: [Int]] else {
            XCTFail("no streamCount"); return
        }
        guard let hist = streamCount["1.0"] else { XCTFail("no histogram for 1.0"); return }
        // net: 3-4=-1(0扱い) + 1 = 1
        XCTAssertEqual(1, hist[1], "subtract後のnet=1でストリーム長1")
    }

    func testStreamBushuSubtract() throws {
        // 部首変換: 基本文字2打鍵後に subtract=2 の確定
        // currentLength の変化: 0 →(+1)→ 1 →(+1)→ 2 →(net=1-2=-1, max(0,2-1)=1)→ 1
        stats.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        // 基本文字2打鍵
        stats.recordKakutei(charCount: 1)
        stats.recordKakutei(charCount: 1)
        // 部首変換確定 subtract=2
        stats.recordKakutei(charCount: 1, subtract: 2)
        stats.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let streamCount = dict["streamCount"] as? [String: [Int]] else {
            XCTFail("no streamCount"); return
        }
        guard let hist = streamCount["1.0"] else { XCTFail("no histogram for 1.0"); return }
        // 1+1 + max(0, 2+(-1)) = 2 + ... → currentLength=1でストリーム終了
        XCTAssertEqual(1, hist[1], "部首変換subtract後のストリーム長1")
    }

    func testStreamCapAt50() throws {
        // 51文字連続入力 → ストリーム長は50にキャップ
        stats.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        for _ in 0..<51 {
            stats.recordKakutei(charCount: 1)
        }
        stats.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let streamCount = dict["streamCount"] as? [String: [Int]] else {
            XCTFail("no streamCount"); return
        }
        guard let hist = streamCount["1.0"] else { XCTFail("no histogram for 1.0"); return }
        XCTAssertEqual(51, hist.count)
        XCTAssertEqual(1, hist[50], "51文字でも50にキャップ")
        XCTAssertEqual(0, hist.enumerated().filter { $0.offset != 50 }.map { $0.element }.reduce(0, +),
                       "インデックス50以外は0")
    }

    func testRecordNonStrokeEventDoesNotEndStream() throws {
        // recordNonStrokeEvent はバイグラムのみ断ち、ストリームは終了しない
        stats.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        stats.recordKakutei(charCount: 2)
        // バイグラム不連続のみ（PendingKakutei受容相当）
        stats.recordNonStrokeEvent()
        stats.recordKakutei(charCount: 1)
        stats.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        stats.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let streamCount = dict["streamCount"] as? [String: [Int]] else {
            XCTFail("no streamCount"); return
        }
        guard let hist = streamCount["1.0"] else { XCTFail("no histogram for 1.0"); return }
        // ストリームは継続して合計3文字
        XCTAssertEqual(1, hist[3], "recordNonStrokeEvent後もストリーム継続して長さ3")
    }

    func testKanjiConversionDeltaPreservesUnchangedKanji() {
        XCTAssertEqual(
            InputStats.KanjiConversionDelta(consumed: 0, introduced: 2),
            InputStats.kanjiConversionDelta(from: "漢字へんかん", to: "漢字変換")
        )
        XCTAssertEqual(
            InputStats.KanjiConversionDelta(consumed: 0, introduced: 1),
            InputStats.kanjiConversionDelta(from: "地しん", to: "地震")
        )
    }

    func testKanjiConversionStatsAreWrittenAsIndependentRecord() throws {
        stats.recordDirectKanji(in: "日月A")
        stats.recordBushuKanjiConversion(source: "日月", result: "明")
        stats.recordMazegakiKanjiConversion(source: "漢字へんかん", result: "漢字変換")

        stats.writeStatsToFile(force: true)

        let record = try String(contentsOf: recordFileURL, encoding: .utf8)
        XCTAssertTrue(record.contains("kanjiDirect=2"))
        XCTAssertTrue(record.contains("kanjiConsumed=2"))
        XCTAssertTrue(record.contains("kanjiBushu=1"))
        XCTAssertTrue(record.contains("kanjiMazegaki=2"))

        // 書き出し後は区間カウンタがリセットされ、追加の空レコードは出力しない。
        stats.writeStatsToFile(force: true)
        XCTAssertEqual(record, try String(contentsOf: recordFileURL, encoding: .utf8))
    }
}
