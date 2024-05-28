//
//  BushuTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/05/28.
//

import XCTest
@testable import MacTcode

final class BushuTests: XCTestCase {
    func testReadTable() {
        XCTAssertNotNil(Bushu.i)
    }
    func testBasicCompose() {
        XCTAssertEqual("照", Bushu.i.basicCompose(char1: "召", char2: "点"), "召点")
        XCTAssertEqual("照", Bushu.i.basicCompose(char1: "点", char2: "召"), "点召")
    }
    func testSubtraction() {
        XCTAssertEqual("圭", Bushu.i.compose(char1: "街", char2: "行"), "街行")
        XCTAssertEqual("圭", Bushu.i.compose(char1: "行", char2: "街"), "行街")
        XCTAssertEqual("口", Bushu.i.compose(char1: "鳴", char2: "鳥"), "鳴鳥")
        XCTAssertEqual("口", Bushu.i.compose(char1: "鳥", char2: "鳴"), "鳥鳴")
        XCTAssertEqual("豆", Bushu.i.compose(char1: "頭", char2: "顔"), "頭顔")
        XCTAssertEqual("彦", Bushu.i.compose(char1: "顔", char2: "頭"), "顔頭")

    }
    func testPartsWise() {
        XCTAssertEqual("記", Bushu.i.compose(char1: "語", char2: "起"), "語起")
        XCTAssertEqual("記", Bushu.i.compose(char1: "起", char2: "語"), "起語")
        XCTAssertEqual("悟", Bushu.i.compose(char1: "語", char2: "性"), "語性")
        XCTAssertEqual("悟", Bushu.i.compose(char1: "性", char2: "語"), "性語")
        XCTAssertEqual("貼", Bushu.i.compose(char1: "店", char2: "買"), "店買")
        XCTAssertEqual("貼", Bushu.i.compose(char1: "買", char2: "店"), "買店")

    }
}

