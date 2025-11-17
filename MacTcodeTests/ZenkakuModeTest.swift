//
//  ZenkakuModeTest.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/06/05.
//

import XCTest
import Cocoa
import InputMethodKit
@testable import MacTcode

final class ZenkakuModeTest: XCTestCase {
    var mode: Mode!
    var spy: RecentTextClient!
    var client: ContextClient!
    var holder: HolderSpy!
    
    class HolderSpy: Controller {
        func setBackspaceIgnore(_ count: Int) {}
        var pendingKakutei: MacTcode.PendingKakuteiMode?
        func setPendingKakutei(_ pending: MacTcode.PendingKakuteiMode?) {}

        var modeStack: [Mode]
        var candidateWindow: IMKCandidates = IMKCandidates()
        init() {
            self.modeStack = []
        }
        func pushMode(_ mode: Mode) {
            modeStack = [mode] + modeStack
        }
        func popMode(_ mode: Mode) {
            if let index = modeStack.firstIndex(where: { $0 === mode }) {
                modeStack.remove(at: index)
            }
        }
        var mode: Mode { get { modeStack.first! } }
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
            let ret = holder.mode.handle(event, client: client)
            XCTAssertEqual(.processed, ret)
        }
    }
    
    override func setUpWithError() throws {
        super.setUp()
        spy = RecentTextClient("", 99)
        client = ContextClient(client: spy, recent: RecentTextClient(""))
        holder = HolderSpy()
        mode = TcodeMode(controller: holder)
        holder.pushMode(mode)
        Log.i("setUp!")
    }
    
    override func tearDownWithError() throws {
        mode = nil
        super.tearDown()
    }
 
    func testHan2Zen() {
        let str = ZenkakuMode(controller: holder).han2zen(" Zenkaku~!")
        XCTAssertEqual("　Ｚｅｎｋａｋｕ￣！", str)
    }
    
    func testHan2ZenModeChange() {
        feed("teso90123ABC#*zenkaku\u{1b}x y z fudefe")
        XCTAssertEqual("のが１２３ＡＢＣ＃＊ｚｅｎｋａｋｕxyzあいう", spy.text)
    }
}
