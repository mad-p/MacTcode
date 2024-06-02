//
//  TranslationTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/06/01.
//

import XCTest
import Cocoa
@testable import MacTcode

final class TranslationTests: XCTestCase {
    var mainloop: TcodeMainloop!
    var spy: RecentText!
    
    func stubCharEvent(_ char: String) -> NSEvent {
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: char, charactersIgnoringModifiers: char, isARepeat: false, keyCode: 0)!
    }
    func stubCodeEvent(_ code: Int, char: String = "a") -> NSEvent {
        return NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: char, charactersIgnoringModifiers: char, isARepeat: false, keyCode: UInt16(code))!
    }
    func feed(_ sequence: String) {
        sequence.forEach { char in
            let event = stubCharEvent(String(char))
            let ret = mainloop.handle(event, client: spy)
            XCTAssertTrue(ret)
        }
    }

    override func setUpWithError() throws {
        super.setUp()
        spy = RecentText("")
        mainloop = TcodeMainloop()
        NSLog("setUp!")
    }
    
    override func tearDownWithError() throws {
        mainloop = nil
        super.tearDown()
    }
    
    func testPassthrough() {
        let event = stubCharEvent("A")
        let ret = mainloop.handle(event, client: spy)
        XCTAssertFalse(ret)
    }
    func testSendFirstBySpace() {
        feed("a ")
        XCTAssertEqual("a", spy.text)
    }
    func testInput() {
        feed("tesoteso")
        XCTAssertEqual("のがのが", spy.text)
    }
    func testBushu() {
        feed("tpkuhus.djue")
        XCTAssertEqual("晴れだね", spy.text)
    }
    func testMazeAutoKakutei() {
        feed("zbtphizuhobeuhsofuhpto")
        XCTAssertEqual("今日は地震があった", spy.text)
    }
    func testOutset() {
        feed("fqyg\\iqioy")
        XCTAssertEqual("全角　空白", spy.text)
    }
    
    func testOutset2() {
        feed("se\\\\dsu\\\\t")
        XCTAssertEqual("1①2③", spy.text)
    }
}
