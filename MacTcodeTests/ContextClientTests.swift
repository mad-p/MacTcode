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
        var setMarkedTextCalled = false
        var setMarkedTextString = ""
        var setMarkedTextSelectionRange: NSRange = NSRange(location: 0, length: 0)
        var setMarkedTextReplacementRange: NSRange = NSRange(location: 0, length: 0)
        var bundleIdentifier: String!
        
        init(selectedRangeValue: NSRange, 
             stringReturnValue: String = "",
             stringReturnRange: NSRange = NSRange(location: 0, length: 0),
             bundleId: String = "jp.mad-p.inputmethod.MacTcode.stub",
             insertCallback: @escaping () -> Void = {}
        ) {
            self.selectedRangeValue = selectedRangeValue
            self.stringReturnValue = stringReturnValue
            self.stringReturnRange = stringReturnRange
            self.insertCallback = insertCallback
            self.bundleIdentifier = bundleId
        }
        func bundleId() -> String! {
            self.bundleIdentifier
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
        func setMarkedText(
            _ string: String,
            selectionRange: NSRange,
            replacementRange: NSRange
        ) {
            setMarkedTextCalled = true
            setMarkedTextString = string
            setMarkedTextSelectionRange = selectionRange
            setMarkedTextReplacementRange = replacementRange
        }
        func sendBackspace() {
            backSpaceCount += 1
        }
        func sendDummyInsertMaybe() {
            // nop
        }
    }
    func testYomiExactFromSelection() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 2),
                                stringReturnValue: "日月",
                                stringReturnRange: NSRange(location: 3, length: 2))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
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
        let yomi = context.getYomi(2, 2, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromSelectionTooShort() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 1))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 5, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromSelectionTooLong() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 8))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 5, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromSelectionGoodLength() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 3),
                                stringReturnValue: "日月火",
                                stringReturnRange: NSRange(location: 3, length: 3))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 5, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
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
        let yomi = context.getYomi(2, 2, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
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
        let yomi = context.getYomi(1, 5, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
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
        let yomi = context.getYomi(2, 2, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromClientNotEnoughText() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0),
                                stringReturnValue: "月",
                                stringReturnRange: NSRange(location: 3, length: 1))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 10, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", yomi.string)
    }
    func testYomiFromMirrorWhenClientHasNoCursor() {
        let client = ClientStub(selectedRangeValue: NSRange(location: NSNotFound, length: NSNotFound))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(2, 2, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
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
        let yomi = context.getYomi(2, 2, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("火水", yomi.string)
        XCTAssertEqual(5, yomi.range.location)
        XCTAssertEqual(2, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
    }
    func testYomiFromMirrorWhenClientReturnsAZeroWidthSpace() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 1, length: 0),
                                stringReturnValue: "\u{200b}",
                                stringReturnRange: NSRange(location: 0, length: 1))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 5, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("うえお火水", yomi.string)
        XCTAssertEqual(2, yomi.range.location)
        XCTAssertEqual(5, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
        XCTAssertTrue(client.stringCalled)
        XCTAssertEqual(NSRange(location: 0, length: 1), client.stringCalledRange)
    }
    func testYomiFromMirrorWhenClientReturnsEmptyString() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 0),
                                stringReturnValue: "")
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 3, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("お火水", yomi.string)
        XCTAssertEqual(4, yomi.range.location)
        XCTAssertEqual(3, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
    }
    func testYomiFromMirrorWhenClientReturnsUnderscore() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 0),
                                stringReturnValue: "_")
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 3, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("お火水", yomi.string)
        XCTAssertEqual(4, yomi.range.location)
        XCTAssertEqual(3, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
    }
    func testYomiFromMirrorWhenClientReturnsOnlyOneCharacter() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 2, length: 0),
                                stringReturnValue: "ん",
                                bundleId: "com.google.Chrome")
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 3, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("お火水", yomi.string)
        XCTAssertEqual(4, yomi.range.location)
        XCTAssertEqual(3, yomi.range.length)
        XCTAssertFalse(yomi.fromSelection)
        XCTAssertTrue(yomi.fromMirror)
    }
    func testYomiFromMirrorWhenClientReturnsLessThanExpected() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 0),
                                stringReturnValue: "わん")
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let yomi = context.getYomi(1, 3, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
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
        let count = context.replaceYomi("木金", length: 2, from: YomiContext(string: "火水", range: NSRange(location: 3, length: 2), fromSelection: true, fromMirror: false))
        XCTAssertTrue(client.insertCalled)
        XCTAssertEqual("木金", client.insertedString)
        XCTAssertEqual(NSRange(location: 3, length: 2), client.insertedRange)
        XCTAssertEqual("あいうえお木金", recent.text)
        XCTAssertEqual(0, count)
    }
    func testReplaceYomiFromClient() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 3, length: 0),
                                stringReturnValue: "火水",
                                stringReturnRange: NSRange(location: 1, length: 2))
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let count = context.replaceYomi("木金", length: 2, from: YomiContext(string: "火水", range: NSRange(location: 1, length: 2), fromSelection: false, fromMirror: false))
        XCTAssertTrue(client.insertCalled)
        XCTAssertEqual("木金", client.insertedString)
        XCTAssertEqual(NSRange(location: 1, length: 2), client.insertedRange)
        XCTAssertEqual("あいうえお木金", recent.text)
        XCTAssertEqual(0, count)
    }
    func testReplaceYomiFromMirror() {
        let expectation = XCTestExpectation(description: "insert called")
        let client = ClientStub(selectedRangeValue: NSRange(location: NSNotFound, length: NSNotFound)) {
            expectation.fulfill()
        }
        let recent = RecentTextClient("あいうえお火水")
        let context = ContextClient(client: client, recent: recent)
        let count = context.replaceYomi("木金", length: 3, from: YomiContext(string: "あいうえお火水", range: NSRange(location: 0, length: 7), fromSelection: false, fromMirror: true))
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(3, client.backSpaceCount)
        XCTAssertEqual(3, count)
        XCTAssertTrue(client.insertCalled)
        XCTAssertEqual("木金", client.insertedString)
        XCTAssertEqual(NSRange(location: NSNotFound, length: NSNotFound), client.insertedRange)
        XCTAssertEqual("あいうえ木金", recent.text)
    }
    
    func testExtractValidYomiSuffixBasic() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "あいうえお", minLength: 1, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("あいうえお", result)
    }
    
    func testExtractValidYomiSuffixWithNonYomiPrefix() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "abc火水", minLength: 1, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("火水", result)
    }
    
    func testExtractValidYomiSuffixMinLength() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "abc火水", minLength: 3, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", result)
    }
    
    func testExtractValidYomiSuffixMinLengthMet() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "abc火水金", minLength: 3, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("火水金", result)
    }
    
    func testExtractValidYomiSuffixEmptyString() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "", minLength: 1, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", result)
    }
    
    func testExtractValidYomiSuffixNoYomiCharacters() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "123abc", minLength: 1, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("", result)
    }
    
    func testExtractValidYomiSuffixMixedWithYomiAtEnd() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "123abcあいうえお", minLength: 1, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("あいうえお", result)
    }
    
    func testExtractValidYomiSuffixOnlyYomiCharacters() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "かきくけこ", minLength: 2, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("かきくけこ", result)
    }
    
    func testExtractValidYomiSuffixZeroMinLength() {
        let client = ClientStub(selectedRangeValue: NSRange(location: 0, length: 0))
        let recent = RecentTextClient("")
        let context = ContextClient(client: client, recent: recent)
        
        let result = context.extractValidYomiSuffix(from: "abc火", minLength: 0, yomiCharacters: UserConfigs.i.bushu.bushuYomiCharacters)
        XCTAssertEqual("火", result)
    }
}
