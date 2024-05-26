//
//  MacTcodeTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/05/25.
//

import XCTest
@testable import MacTcode

final class MacTcodeTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTranslate() throws {
        XCTAssertEqual(27, TcodeTable.translateKey(text: "t"), "t")
        XCTAssertEqual(22, TcodeTable.translateKey(text: "e"), "e")
        XCTAssertNil(TcodeTable.translateKey(text: "+"), "not found")
    }
    
    func testLookup() throws {
        XCTAssertEqual("の", TcodeTable.lookup(i: 27, j:22), "の")
        XCTAssertEqual("識", TcodeTable.lookup(i: 7, j:32), "識")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
