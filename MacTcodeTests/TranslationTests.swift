//
//  TranslationTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/06/01.
//

import XCTest
import Cocoa
import InputMethodKit
@testable import MacTcode

final class TranslationTests: XCTestCase {
    var mode: TcodeMode!
    var spy: RecentTextClient!
    var client: ContextClient!
    
    class HolderSpy: Controller {
        func setBackspaceIgnore(_ count: Int) {}
        var pendingKakutei: MacTcode.PendingKakutei?
        func setPendingKakutei(_ pending: MacTcode.PendingKakutei?) {}
        
        var mode: Mode
        var candidateWindow: IMKCandidates = IMKCandidates() // dummy
        init(mode: Mode) {
            self.mode = mode
        }
        func pushMode(_ mode: Mode) {
            self.mode = mode
        }
        func popMode() {
        }
    }
    
    func stubCharEvent(_ char: String) -> InputEvent {
        return Translator.translate(event: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: char, charactersIgnoringModifiers: char, isARepeat: false, keyCode: 0)!)
    }
    func stubCodeEvent(_ code: Int, char: String = "a") -> InputEvent {
        return Translator.translate(event: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: char, charactersIgnoringModifiers: char, isARepeat: false, keyCode: UInt16(code))!)
    }
    func feed(_ sequence: String) {
        sequence.forEach { char in
            let event = stubCharEvent(String(char))
            let ret = mode.handle(event, client: client, controller: HolderSpy(mode: mode))
            XCTAssertTrue(ret)
        }
    }

    override func setUpWithError() throws {
        super.setUp()
        spy = RecentTextClient("")
        client = ContextClient(client: spy, recent: RecentTextClient(""))
        mode = TcodeMode()
        Log.i("setUp!")
    }
    
    override func tearDownWithError() throws {
        mode = nil
        super.tearDown()
    }
    
    func testPassthrough() {
        let event = stubCharEvent("A")
        let ret = mode.handle(event, client: client, controller: HolderSpy(mode: mode))
        XCTAssertFalse(ret)
    }
    func testSendFirstBySpace() {
        feed(" a  ")
        XCTAssertEqual(" a ", spy.text)
    }
    func testSendFirstBySpace2() {
        feed("\\\\ ")
        XCTAssertEqual("\\\\", spy.text)
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
        feed("zbtphizawvfe.ouhtid;hpto")
        XCTAssertEqual("今日は調査に行った", spy.text)
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
