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
        let e1 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(27), text: "t"))
        switch e1 {
        case .next(let m2):
            let e2 = m2.lookup(input: InputEvent(type: .printable(22), text: "e"))
            switch e2 {
            case .command(let c2):
                switch c2 {
                case .text(let string):
                    XCTAssertEqual("の", string)
                default:
                    XCTFail()
                }
            default:
                XCTFail()
            }
        default:
            XCTFail()
        }
    }
    
    /*
    
    func testReset() {
        TcodeKeymap.map.reset()
        _ = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(27), text: "t"))
        TcodeKeymap.map.reset()
        let c1 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(29), text: "s"))
        switch c1 {
        case .pending:
            XCTAssertTrue(true)
        default:
            XCTFail("should return .pending")
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
        case .pending:
            XCTAssertTrue(true)
        default:
            XCTFail("should return .pending")
        }
        
        let c2 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(23), text: "u"))
        switch c2 {
        case .action(let action):
            XCTAssertTrue(action is PostfixBushuAction)
        default:
            XCTFail("should return PositfixBushuAction")
        }
    }
    
     */
    
    func testStrokeKeymap1() {
        guard let k = StrokeKeymap("testmap", fromChars: "√∂『』　《》【】“┏┳┓┃◎◆■●▲▼┣╋┫━　◇□○△▽┗┻┛／＼※§¶†‡")
        else {
            XCTFail()
            return
        }
        let e1 = k.lookup(input: InputEvent(type: .printable(24)))
        switch e1 {
        case .command(let c1):
            switch c1 {
            case .text(let string):
                XCTAssertEqual("　", string)
            default:
                XCTFail()
            }
        default:
            XCTFail()
        }
    }
    
    /*
    func testOutset1() {
        TcodeKeymap.map.reset()
        let c1 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(nil), text: "\\"))
        switch c1 {
        case .pending:
            XCTAssertTrue(true)
        default:
            XCTFail("should return .pending")
        }
        let c2 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable(24), text: "i"))
        switch c2 {
        case .text(let string, let array):
            XCTAssertEqual("　", string)
            XCTAssertEqual([24], array)
        default:
            XCTFail("should return .text")
        }
    }
     */
}
