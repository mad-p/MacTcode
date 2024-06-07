//
//  ZenkakuModeTest.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/06/05.
//

import XCTest
import Cocoa
@testable import MacTcode

final class ZenkakuModeTest: XCTestCase {
    var mode: Mode!
    var spy: RecentTextClient!
    var holder: HolderSpy!
    
    class HolderSpy: ModeHolder {
        var mode: Mode
        init(mode: Mode) {
            self.mode = mode
        }
        func setMode(_ mode: Mode) {
            self.mode = mode
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
            let ret = holder.mode.handle(event, client: spy, modeHolder: holder)
            XCTAssertTrue(ret)
        }
    }
    
    override func setUpWithError() throws {
        super.setUp()
        spy = RecentTextClient("", 99)
        mode = ZenkakuMode()
        holder = HolderSpy(mode: mode)
        NSLog("setUp!")
    }
    
    override func tearDownWithError() throws {
        mode = nil
        super.tearDown()
    }
 
    func testHan2Zen() {
        let str = ZenkakuMode().han2zen(" Zenkaku~!")
        XCTAssertEqual("　Ｚｅｎｋａｋｕ￣！", str)
    }
    
    func testHan2ZenModeChange() {
        holder.setMode(TcodeMode())
        feed("teso90123ABC#*zenkaku\u{1b}x y z fudefe")
        XCTAssertEqual("のが１２３ＡＢＣ＃＊ｚｅｎｋａｋｕxyzあいう", spy.text)
    }
}