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
        var insertCallback: () -> Void = {}
        var selectedRangeValue = NSRange(location: 0, length: 0)
        var selectedRangeCalled = false
        var stringReturnValue = ""
        var stringReturnRange = NSRange(location: 0, length: 0)
        var stringCalledRange = NSRange(location: 0, length: 0)
        var stringCalled = false
        
        init(selectedRangeValue: NSRange, 
             stringReturnValue: String = "",
             stringReturnRange: NSRange = NSRange(location: 0, length: 0),
             insertCallback: @escaping () -> Void = {}
        ) {
            self.selectedRangeValue = selectedRangeValue
            self.stringReturnValue = stringReturnValue
            self.stringReturnRange = stringReturnRange
            self.insertCallback = insertCallback
        }
        func selectedRange() -> NSRange {
            selectedRangeCalled = true
            return selectedRangeValue
        }
        func string(from range: NSRange, actualRange: NSRangePointer) -> String! {
            stringCalled = true
            stringCalledRange = range
            actualRange.pointee = stringReturnRange
            return stringReturnValue
        }
        func insertText(_ string: String, replacementRange rr: NSRange) {
            insertCalled = true
            insertedString = string
            insertedRange = rr
            insertCallback()
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
    func testYomiFromSelectionTooShort() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 1))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 5)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromSelectionTooLong() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 8))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 5)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromSelectionGoodLength() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 3),
                                stringReturnValue: "日月火",
                                stringReturnRange: NSRange(location: 3, length: 3))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 5)
        XCTAssertEqual("日月火", yomi.string)
        XCTAssertEqual(3, yomi.range.location)
        XCTAssertEqual(3, yomi.range.length)
        XCTAssertTrue(yomi.fromSelection)
        XCTAssertFalse(yomi.fromMirror)
        XCTAssertEqual(NSRange(location: 3, length: 3), client.selectedRangeValue)
    }
    func testYomiExactFromClient() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 33, length: 0),
                                stringReturnValue: "日月",
                                stringReturnRange: NSRange(location: 31, length: 2))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2)
        XCTAssertEqual("日月", yomi.string)
        XCTAssertEqual(31, yomi.range.location)
        XCTAssertEqual(2, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertFalse(yomi.fromMirror)
        XCTAssertTrue(client.stringCalled)
        XCTAssertEqual(NSRange(location: 31, length: 2), client.stringCalledRange)
    }
    func testYomiFromClient() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 0),
                                stringReturnValue: "日月火",
                                stringReturnRange: NSRange(location: 0, length: 3))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 5)
        XCTAssertEqual("日月火", yomi.string)
        XCTAssertEqual(0, yomi.range.location)
        XCTAssertEqual(3, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertFalse(yomi.fromMirror)
        XCTAssertTrue(client.stringCalled)
        XCTAssertEqual(NSRange(location: 0, length: 3), client.stringCalledRange)
    }
    func testYomiExactFromClientNotEnoughText() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 1, length: 0),
                                stringReturnValue: "月",
                                stringReturnRange: NSRange(location: 3, length: 1))
        let recent = RecentTextClient("水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromClientNotEnoughText() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0),
                                stringReturnValue: "月",
                                stringReturnRange: NSRange(location: 3, length: 1))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 10)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromMirrorWhenClientHasNoCursor() {
        let client = ClientStub(selectedRangeValue: NSRange(location: NSNotFound, length: NSNotFound))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2)
        XCTAssertEqual("火水", yomi.string)
        XCTAssertEqual(5, yomi.range.location)
        XCTAssertEqual(2, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
    }
    func testYomiFromMirrorWhenClientTextTooShort() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 1, length: 0))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2)
        XCTAssertEqual("火水", yomi.string)
        XCTAssertEqual(5, yomi.range.location)
        XCTAssertEqual(2, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
    }
    func testYomiFromMirrorWhenClientReturnsEmptyString() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 0),
                                stringReturnValue: "")
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 3)
        XCTAssertEqual("お火水", yomi.string)
        XCTAssertEqual(4, yomi.range.location)
        XCTAssertEqual(3, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
    }

    func testReplaceYomiFromSelection() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 2))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        context.replaceYomi("木金", length: 2, from: YomiContext(string: "火水", range: NSRange(location: 3, length: 2), fromSelection: true, fromMirror: false))
        XCTAssertTrue(client.insertCalled)
        XCTAssertEqual("木金", client.insertedString)
        XCTAssertEqual(NSRange(location: 3, length: 2), client.insertedRange)
        XCTAssertEqual("あいうえお木金", recent.text)
    }
    func testReplaceYomiFromClient() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 0),
                                stringReturnValue: "火水",
                                stringReturnRange: NSRange(location: 1, length: 2))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        context.replaceYomi("木金", length: 2, from: YomiContext(string: "火水", range: NSRange(location: 1, length: 2), fromSelection: false, fromMirror: false))
        XCTAssertTrue(client.insertCalled)
        XCTAssertEqual("木金", client.insertedString)
        XCTAssertEqual(NSRange(location: 1, length: 2), client.insertedRange)
        XCTAssertEqual("あいうえお木金", recent.text)
    }
    func testReplaceYomiFromMirror() {
        let expectation = XCTestExpectation(description: "insert called")
        let client = ClientStub(selectedRangeValue: NSRange(location: NSNotFound, length: NSNotFound)) {
            expectation.fulfill()
        }
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        context.replaceYomi("木金", length: 3, from: YomiContext(string: "あいうえお火水", range: NSRange(location: 0, length: 7), fromSelection: false, fromMirror: true))
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(3, client.backSpaceCount)
        XCTAssertTrue(client.insertCalled)
        XCTAssertEqual("木金", client.insertedString)
        XCTAssertEqual(NSRange(location: NSNotFound, length: NSNotFound), client.insertedRange)
        XCTAssertEqual("あいうえ木金", recent.text)
    }
}
