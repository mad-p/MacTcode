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
        let r = RecentText("今日は晴れxでしたね")
        XCTAssertEqual("今日は晴れxでしたね", r.text)
        r.append("明日は雨かもyしれないですね")
        XCTAssertEqual("れxでしたね明日は雨かもyしれないですね", r.text)
    }
    func testCursor() {
        let r = RecentText("気持ちいい朝です")
        let cursor = r.selectedRange()
        XCTAssertEqual(8, cursor.location)
        XCTAssertEqual(0, cursor.length)
    }
    func testString() {
        let r = RecentText("気持ちいい朝です")
        var actual = NSRange(location: NSNotFound, length: NSNotFound)
        let string = r.string(from: NSRange(location:6, length:2), actualRange: &actual)
        XCTAssertEqual("です", string)
        XCTAssertEqual(6, actual.location)
        XCTAssertEqual(2, actual.length)
    }
}
