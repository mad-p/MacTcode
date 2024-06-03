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
        let e1 = TcodeKeymap.map.lookup(input: InputEvent(type: .printable, text: "t"))
        switch e1 {
        case .keymap(let m2):
            let c2 = m2.lookup(input: InputEvent(type: .printable, text: "e"))
            switch c2 {
            case .text(let string):
                XCTAssertEqual("の", string)
            default:
                XCTFail()
            }
        default:
            XCTFail()
        }
    }
    
    
    func testKeymap1() {
        guard let k = Keymap("testmap", fromChars: "√∂『』　《》【】“┏┳┓┃◎◆■●▲▼┣╋┫━　◇□○△▽┗┻┛／＼※§¶†‡")
        else {
            XCTFail()
            return
        }
        let c1 = k.lookup(input: InputEvent(type: .printable, text: "i"))
        switch c1 {
        case .text(let string):
            XCTAssertEqual("　", string)
        default:
            XCTFail()
        }
    }
}
