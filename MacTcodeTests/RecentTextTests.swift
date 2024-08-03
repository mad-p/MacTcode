//
//  RecentTextTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/06/01.
//

import XCTest
@testable import MacTcode

final class RecentTextTests: XCTestCase {
    func testTrim() {
        let r = RecentTextClient("今日は晴れxでしたね")
        XCTAssertEqual("今日は晴れxでしたね", r.text)
        r.append("明日は雨かもyしれないですね")
        XCTAssertEqual("れxでしたね明日は雨かもyしれないですね", r.text)
    }
    func testCursor() {
        let r = RecentTextClient("気持ちいい朝です")
        let cursor = r.selectedRange()
        XCTAssertEqual(8, cursor.location)
        XCTAssertEqual(0, cursor.length)
    }
    func testString() {
        let r = RecentTextClient("気持ちいい朝です")
        var actual = NSRange(location: NSNotFound, length: NSNotFound)
        let string = r.string(from: NSRange(location:6, length:2), actualRange: &actual)
        XCTAssertEqual("です", string)
        XCTAssertEqual(6, actual.location)
        XCTAssertEqual(2, actual.length)
    }
    func testInsert() {
        let r = RecentTextClient("気持ちいい朝です")
        r.insertText("なるほどね", replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        XCTAssertEqual("気持ちいい朝ですなるほどね", r.text)
    }
    func testInsertReplace() {
        let r = RecentTextClient("気持ちいい朝です")
        let rr = NSRange(location: 3, length: 3)
        r.insertText("なるほどね", replacementRange: rr)
        XCTAssertEqual("気持ちなるほどねです", r.text)
    }
    func testReplaceLast() {
        let r = RecentTextClient("気持ちいい朝です")
        r.replaceLast(length: 2, with: "だよ")
        XCTAssertEqual("気持ちいい朝だよ", r.text)
    }
}
