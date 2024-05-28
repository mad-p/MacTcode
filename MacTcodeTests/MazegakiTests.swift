//
//  MazegakiTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/05/29.
//

import XCTest
@testable import MacTcode

final class MazegakiTests: XCTestCase {
    func testReadDict() {
        XCTAssertNotNil(MazegakiDict.i)
        XCTAssertNotNil(MazegakiDict.i.dict.count > 0)
    }
    func testLookup() {
        XCTAssertNotNil(MazegakiDict.i.dict["一らん"])
        XCTAssertNil(MazegakiDict.i.dict["ほげら"])
    }
    func testMazegakiState() {
        let m = Mazegaki("今日は地しん", inflection: false, fixed: false)
        XCTAssertEqual(m.max, 6)
        XCTAssertEqual("地しん", m.key(3))
        XCTAssertEqual("地—", m.key(3, offset: 2))
        XCTAssertNil(m.key(8))
        XCTAssertNil(m.key(4, offset: 4))
    }
    func testMazegakiFind() {
        let m1 = Mazegaki("今日は地しん", inflection: false, fixed: false)
        XCTAssertTrue(m1.find(start: 6))
        XCTAssertEqual(3, m1.length)
        XCTAssertTrue(m1.found)
        let m2 = Mazegaki("今日は地信ん", inflection: false, fixed: false)
        XCTAssertFalse(m2.find(start: 6))
        XCTAssertFalse(m2.found)
    }
}
