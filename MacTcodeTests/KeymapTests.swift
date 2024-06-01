//
//  MacTcodeTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/05/25.
//

import XCTest
@testable import MacTcode

final class KeymapTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLookup() {
        TcodeKeymap.map.reset()
        let c1 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(27), text: "t"))
        switch c1 {
        case .processed:
            XCTAssertTrue(true)
        default:
            XCTFail("should return .processed")
        }
        
        let c2 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(22), text: "e"))
        switch c2 {
        case .text(let string, let array):
            XCTAssertEqual("の", string)
            XCTAssertEqual([27, 22], array)
        default:
            XCTFail("should return .text")
        }
    }
    
    func testReset() {
        TcodeKeymap.map.reset()
        _ = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(27), text: "t"))
        TcodeKeymap.map.reset()
        let c1 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(29), text: "s"))
        switch c1 {
        case .processed:
            XCTAssertTrue(true)
        default:
            XCTFail("should return .processed")
        }
        
        let c2 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(21), text: "o"))
        switch c2 {
        case .text(let string, let array):
            XCTAssertEqual("が", string)
            XCTAssertEqual([29, 21], array)
        default:
            XCTFail("should return .text")
        }
    }
    
    func testEmbed() {
        TcodeKeymap.map.reset()
        let c1 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(26), text: "h"))
        switch c1 {
        case .processed:
            XCTAssertTrue(true)
        default:
            XCTFail("should return .processed")
        }
        
        let c2 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(23), text: "u"))
        switch c2 {
        case .action(let action):
            XCTAssertTrue(action is PostfixBushuAction)
        default:
            XCTFail("should return PositfixBushuAction")
        }
    }
}
