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
    func y(_ string: String, fixed: Bool = false) -> YomiContext {
        return YomiContext(string: string, range: NSRange(location: 0, length: string.count), fromSelection: fixed, fromMirror: false)
    }
    func testMazegakiState() {
        let m = Mazegaki(y("今日は地しん"), inflection: false)
        XCTAssertEqual(m.max, 6)
        XCTAssertEqual("地しん", m.key(3))
        XCTAssertEqual("地—", m.key(3, offset: 2))
        XCTAssertNil(m.key(8))
        XCTAssertNil(m.key(4, offset: 4))
    }
    func testMazegakiFind() {
        let m1 = Mazegaki(y("今日のはにわ"), inflection: false)
        let rs1 = m1.find()
        XCTAssertEqual(3, rs1.count)
        
        let r1 = rs1[0]
        XCTAssertEqual("はにわ", r1.key)
        XCTAssertTrue(r1.found)
        XCTAssertEqual(3, r1.length)
        
        let r2 = rs1[1]
        XCTAssertEqual("にわ", r2.key)
        XCTAssertTrue(r2.found)
        XCTAssertEqual(2, r2.length)

        let r3 = rs1[2]
        XCTAssertEqual("わ", r3.key)
        XCTAssertTrue(r3.found)
        XCTAssertEqual(1, r3.length)
        
        let m2 = Mazegaki(y("今日は地信ん"), inflection: false)
        let rs2 = m2.find()
        XCTAssertEqual(0, rs2.count)
    }
    func testMazegakiFindFixed() {
        let m1 = Mazegaki(y("はにわ", fixed: true), inflection: false)
        let rs1 = m1.find()
        XCTAssertEqual(1, rs1.count)
        let r1 = rs1[0]
        XCTAssertEqual("はにわ", r1.key)
        XCTAssertTrue(r1.found)
        XCTAssertEqual(3, r1.length)
    }
    func testMazegakiNonYomiChars() {
        let m1 = Mazegaki(y("なんだ、さくじょ"), inflection: false)
        XCTAssertEqual(4, m1.max)
    }
    func testMazegakiHitCands() {
        let m1 = Mazegaki(y("地しん", fixed: true), inflection: false)
        let rs1 = m1.find()
        XCTAssertEqual(1, rs1.count)
        let c1 = rs1[0].candidates()
        XCTAssertEqual(["地震"], c1)
        let m2 = Mazegaki(y("そう作", fixed: true), inflection: false)
        let rs2 = m2.find()
        XCTAssertEqual(1, rs2.count)
        let c2 = rs2[0].candidates()
        XCTAssertEqual(Set(["操作", "創作"]), Set(c2))
    }
    func testMazegakiInflection() {
        let m = Mazegaki(y("うけたまわる"), inflection: true)
        let rs = m.find()
        let expectedResult = ["承る", "賜る", "回る", "割る"]
        let nonExpectedResult = ["賜", "玉"]
        let allCandidates = rs.flatMap{ $0.candidates() }
        expectedResult.forEach { str in
            XCTAssertTrue(allCandidates.contains(str), "\(str) should be in candidates")
        }
        nonExpectedResult.forEach { str in
            XCTAssertFalse(allCandidates.contains(str), "\(str) should not be in candidates")
        }

    }
}
