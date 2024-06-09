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
        let r1 = m1.find(nil)
        XCTAssertNotNil(r1)
        XCTAssertEqual("地しん", r1!.key)
        XCTAssertTrue(r1!.found)
        XCTAssertEqual(3, r1!.length)
        let r1_1 = m1.find(r1)
        XCTAssertNotNil(r1_1)
        XCTAssertTrue(r1_1!.found)
        XCTAssertEqual("しん", r1_1!.key)
        XCTAssertEqual(2, r1_1!.length)
        let r1_2 = m1.find(r1_1)
        XCTAssertFalse(r1_2!.found)
        
        let m2 = Mazegaki("今日は地信ん", inflection: false, fixed: false)
        let r2 = m2.find(nil)
        XCTAssertNotNil(r2)
        XCTAssertFalse(r2!.found)
    }
    func testMazegakiFindFixed() {
        let m1 = Mazegaki("地しん", inflection: false, fixed: true)
        let r1 = m1.find(nil)
        XCTAssertNotNil(r1)
        XCTAssertEqual("地しん", r1!.key)
        XCTAssertTrue(r1!.found)
        
        let r1_1 = m1.find(r1)
        XCTAssertNotNil(r1_1)
        XCTAssertFalse(r1_1!.found)
    }
    func testMazegakiNonYomiChars() {
        let m1 = Mazegaki("なんだ、さくじょ", inflection: false, fixed: false)
        XCTAssertEqual(4, m1.max)
    }
    func testMazegakiHitCands() {
        let m1 = Mazegaki("地しん", inflection: false, fixed: true)
        let r1 = m1.find(nil)
        let c1 = r1?.candidates()
        XCTAssertEqual(["地震"], c1)
        let m2 = Mazegaki("そう作", inflection: false, fixed: true)
        let r2 = m2.find(nil)
        let c2 = r2?.candidates()
        XCTAssertEqual(Set(["操作", "創作"]), Set(c2!))
    }
    func testMazegakiInflection() {
        let m = Mazegaki("うけたまわる", inflection: true, fixed: true)
        let expected: [(Bool, [String])] = [
            (true, ["承る"]),
            (true, ["受けたまわる", "承けたまわる", "請けたまわる"]),
            (false, [])
        ]
        var r: MazegakiHit? = nil
        expected.forEach { (found, cand) in
            r = m.find(r)
            XCTAssertNotNil(r)
            NSLog("found=\(found)  r!.found=\(r!.found)")
            XCTAssertEqual(found, r!.found)
            if (r!.found) {
                let c = r!.candidates()
                XCTAssertEqual(cand, c)
            }
        }
    }
}
