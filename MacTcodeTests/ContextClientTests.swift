//
//  ContextClientTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/08/17.
//

import XCTest
@testable import MacTcode

final class ContextClientTests: XCTestCase {
    class ClientStub: Client {
        var backSpaceCount = 0
        var insertedString = ""
        var insertedRange = NSRange(location: 0, length: 0)
        var insertCalled = false
        var selectedRangeValue = NSRange(location: 0, length: 0)
        var selectedRangeCalled = false
        var stringReturnValue = ""
        var stringReturnRange = NSRange(location: 0, length: 0)
        var stringCalled = false
        
        init(selectedRangeValue: NSRange, stringReturnValue: String = "", stringReturnRange: NSRange = NSRange(location: 0, length: 0)) {
            self.selectedRangeValue = selectedRangeValue
            self.stringReturnValue = stringReturnValue
            self.stringReturnRange = stringReturnRange
        }
        func selectedRange() -> NSRange {
            selectedRangeCalled = true
            return selectedRangeValue
        }
        func string(from range: NSRange, actualRange: NSRangePointer) -> String! {
            stringCalled = true
            actualRange.pointee = stringReturnRange
            return stringReturnValue
        }
        func insertText(_ string: String, replacementRange rr: NSRange) {
            insertCalled = true
            insertedString = string
            insertedRange = rr
        }
        func sendBackspace() {
            backSpaceCount += 1
        }
    }
    func testYomiExactFromSelection() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 2),
                                stringReturnValue: "日月",
                                stringReturnRange: NSRange(location: 3, length: 2))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2)
        XCTAssertEqual("日月", yomi.string)
        XCTAssertEqual(3, yomi.range.location)
        XCTAssertEqual(2, yomi.range.length)
        XCTAssertTrue(yomi.fromSelection)
        XCTAssertFalse(yomi.fromMirror)
        XCTAssertEqual(NSRange(location: 3, length: 2), client.selectedRangeValue)
    }
    func testYomiExactFromSelectionLengthMismatch() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 1),
                                stringReturnValue: "月",
                                stringReturnRange: NSRange(location: 3, length: 1))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiShorterFromSelection() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 20),
                                stringReturnValue: "日月火水木金土日月火",
                                stringReturnRange: NSRange(location: 13, length: 10))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 10)
        XCTAssertEqual("", yomi.string)
        /*XCTAssertEqual("日月火水木金土日月火", yomi.string)
        XCTAssertEqual(13, yomi.range.location)
        XCTAssertEqual(10, yomi.range.length)
        XCTAssertTrue(yomi.fromSelection)
        XCTAssertFalse(yomi.fromMirror)
        XCTAssertEqual(NSRange(location: 13, length: 10), client.selectedRangeValue)*/
    }
}
