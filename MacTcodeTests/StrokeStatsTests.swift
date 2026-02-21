import XCTest
@testable import MacTcode

final class StrokeStatsTests: XCTestCase {
    let fileURL = UserConfigs.i.configFileURL("stroke-stats.json")

    override func setUpWithError() throws {
        // テスト前にファイルを消してクリーンな状態にする
        try? FileManager.default.removeItem(at: fileURL)
        InputStats.i.resetStrokeStats()
        // ensure enabled
        let s = UserConfigs.i.system
        let newSystem = UserConfigs.SystemConfig(
            recentTextMaxLength: s.recentTextMaxLength,
            excludedApplications: s.excludedApplications,
            disableOneYomiApplications: s.disableOneYomiApplications,
            dummyInsertTextApps: s.dummyInsertTextApps,
            logEnabled: s.logEnabled,
            keyboardLayout: s.keyboardLayout,
            keyboardLayoutMapping: s.keyboardLayoutMapping,
            syncStatsInterval: s.syncStatsInterval,
            cancelPeriod: s.cancelPeriod,
            strokeStatsEnabled: true
        )
        UserConfigs.i.updateSystem(newSystem)
    }

    override func tearDownWithError() throws {
        // restore default enabled state
        let s = UserConfigs.i.system
        let newSystem = UserConfigs.SystemConfig(
            recentTextMaxLength: s.recentTextMaxLength,
            excludedApplications: s.excludedApplications,
            disableOneYomiApplications: s.disableOneYomiApplications,
            dummyInsertTextApps: s.dummyInsertTextApps,
            logEnabled: s.logEnabled,
            keyboardLayout: s.keyboardLayout,
            keyboardLayoutMapping: s.keyboardLayoutMapping,
            syncStatsInterval: s.syncStatsInterval,
            cancelPeriod: s.cancelPeriod,
            strokeStatsEnabled: true
        )
        UserConfigs.i.updateSystem(newSystem)
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
        // force sync and write
        InputStats.i.writeStrokeStatsToFile()

        let dict = try loadStats()
        guard let keyCount = dict["keyCount"] as? [Int] else { XCTFail("no keyCount"); return }
        guard let bigram = dict["bigram"] as? [Int] else { XCTFail("no bigram"); return }
        guard let alternation = dict["alternation"] as? [String: Int] else { XCTFail("no alternation"); return }

        XCTAssertEqual(1, keyCount[2])
        XCTAssertEqual(1, keyCount[7])
        let idx = 2 * 40 + 7
        XCTAssertEqual(1, bigram[idx])
        // alternation: first for first stroke, then alternate for L->R
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
        // both should be counted as first
        XCTAssertEqual(2, alternation["first"])
    }

    func testDisabledDoesNotWrite() throws {
        // disable
        let s = UserConfigs.i.system
        let newSystem = UserConfigs.SystemConfig(
            recentTextMaxLength: s.recentTextMaxLength,
            excludedApplications: s.excludedApplications,
            disableOneYomiApplications: s.disableOneYomiApplications,
            dummyInsertTextApps: s.dummyInsertTextApps,
            logEnabled: s.logEnabled,
            keyboardLayout: s.keyboardLayout,
            keyboardLayoutMapping: s.keyboardLayoutMapping,
            syncStatsInterval: s.syncStatsInterval,
            cancelPeriod: s.cancelPeriod,
            strokeStatsEnabled: false
        )
        UserConfigs.i.updateSystem(newSystem)

        InputStats.i.resetStrokeStats()
        InputStats.i.recordStroke(key: 5)
        InputStats.i.writeStrokeStatsToFile()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
