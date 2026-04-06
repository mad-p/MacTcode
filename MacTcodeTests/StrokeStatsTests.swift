import XCTest
@testable import MacTcode

final class StrokeStatsTests: XCTestCase {
    let fileURL = UserConfigs.i.configFileURL("stroke-stats.json")

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
        try? FileManager.default.removeItem(at: fileURL)
        InputStats.i.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem())
    }

    override func tearDownWithError() throws {
        UserConfigs.i.updateSystem(makeSystem())
        try? FileManager.default.removeItem(at: fileURL)
    }

    func loadStats() throws -> [String: Any] {
        let data = try Data(contentsOf: fileURL)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else { throw NSError(domain: "Test", code: 1) }
        return dict
    }

    func testRecordStrokeAndBigram() throws {
        InputStats.i.resetStrokeStats()
        InputStats.i.recordStroke(key: 2)
        InputStats.i.recordStroke(key: 7)
        InputStats.i.writeStrokeStatsToFile()

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
        InputStats.i.resetStrokeStats()
        InputStats.i.recordStroke(key: 1)
        InputStats.i.recordNonStrokeEvent()
        InputStats.i.recordStroke(key: 3)
        InputStats.i.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let bigram = dict["bigram"] as? [Int] else { XCTFail("no bigram"); return }
        let idx = 1 * 40 + 3
        XCTAssertEqual(0, bigram[idx])
        guard let alternation = dict["alternation"] as? [String: Int] else { XCTFail("no alternation"); return }
        XCTAssertEqual(2, alternation["first"])
    }

    func testDisabledDoesNotWrite() throws {
        UserConfigs.i.updateSystem(makeSystem(strokeStatsEnabled: false))
        InputStats.i.resetStrokeStats()
        InputStats.i.recordStroke(key: 5)
        InputStats.i.writeStrokeStatsToFile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - ストリーム統計テスト

    func testStreamSingleStream() throws {
        // 連続した3文字入力でストリーム長3が記録される
        InputStats.i.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        InputStats.i.recordKakutei(charCount: 1)
        InputStats.i.recordKakutei(charCount: 1)
        InputStats.i.recordKakutei(charCount: 1)
        // ストリーム終了
        InputStats.i.recordStreamEndEvent()
        let exp = expectation(description: "barrier queue flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        InputStats.i.writeStrokeStatsToFile()

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
        InputStats.i.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["0.5", "1.0"]))
        InputStats.i.recordKakutei(charCount: 1)
        InputStats.i.recordKakutei(charCount: 1)

        // 0.6秒待機（0.5秒しきい値を超えるが1.0秒しきい値は超えない）
        let wait1 = expectation(description: "wait 0.6s")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.65) { wait1.fulfill() }
        wait(for: [wait1], timeout: 2.0)

        InputStats.i.recordKakutei(charCount: 1)

        // ストリーム終了
        InputStats.i.recordStreamEndEvent()
        let wait2 = expectation(description: "barrier flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { wait2.fulfill() }
        wait(for: [wait2], timeout: 1.0)

        InputStats.i.writeStrokeStatsToFile()

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
        InputStats.i.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        // ヨミ4文字打鍵済みとして subtract: 4、確定3文字
        InputStats.i.recordKakutei(charCount: 3, subtract: 4)
        InputStats.i.recordKakutei(charCount: 1)
        InputStats.i.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        InputStats.i.writeStrokeStatsToFile()

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
        InputStats.i.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        // 基本文字2打鍵
        InputStats.i.recordKakutei(charCount: 1)
        InputStats.i.recordKakutei(charCount: 1)
        // 部首変換確定 subtract=2
        InputStats.i.recordKakutei(charCount: 1, subtract: 2)
        InputStats.i.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        InputStats.i.writeStrokeStatsToFile()

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
        InputStats.i.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        for _ in 0..<51 {
            InputStats.i.recordKakutei(charCount: 1)
        }
        InputStats.i.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        InputStats.i.writeStrokeStatsToFile()

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
        InputStats.i.resetStrokeStats()
        UserConfigs.i.updateSystem(makeSystem(streamThresholds: ["1.0"]))
        InputStats.i.recordKakutei(charCount: 2)
        // バイグラム不連続のみ（PendingKakutei受容相当）
        InputStats.i.recordNonStrokeEvent()
        InputStats.i.recordKakutei(charCount: 1)
        InputStats.i.recordStreamEndEvent()
        let exp = expectation(description: "flush")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        InputStats.i.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let streamCount = dict["streamCount"] as? [String: [Int]] else {
            XCTFail("no streamCount"); return
        }
        guard let hist = streamCount["1.0"] else { XCTFail("no histogram for 1.0"); return }
        // ストリームは継続して合計3文字
        XCTAssertEqual(1, hist[3], "recordNonStrokeEvent後もストリーム継続して長さ3")
    }
}
