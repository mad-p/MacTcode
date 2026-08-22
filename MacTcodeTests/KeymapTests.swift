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
    
    func testKeymap2() {
        let keyBindings = UserConfigs.i.keyBindings
        let basicTableString = keyBindings.basicTable.joined(separator: "\n")
        
        let k = Keymap("TCode2D", from2d: basicTableString)
        
        let ev = InputEvent(type: .printable, text: "`")
        k.replace(input: ev, entry: .text("hoge"))
        let c1 = k.lookup(input: InputEvent(type: .printable, text: "`"))
        switch c1 {
        case .text(let string):
            XCTAssertEqual("hoge", string)
        default:
            XCTFail()
        }
    }

    func testDeclarativeActionBindings() {
        let keymap = Keymap("test-actions")
        applyActionBindings([
            UserConfigs.ActionBindingConfig(keys: "xy", action: "unknown", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "xy", action: "directMode", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "ab", action: "selfInsertAndDirectMode", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "cd", action: "directMode", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "cd", action: "zenkakuMode", inflection: nil, text: nil)
        ], to: keymap, ui: .default)

        let xy = ["x", "y"].map { InputEvent(type: .printable, text: $0) }
        let ab = ["a", "b"].map { InputEvent(type: .printable, text: $0) }
        let cd = ["c", "d"].map { InputEvent(type: .printable, text: $0) }

        if case .action(let action) = KeymapResolver.resolve(keySequence: xy, keymap: keymap) {
            XCTAssertTrue(action is DirectModeAction)
        } else {
            XCTFail("A valid binding after an invalid binding should be applied")
        }
        if case .passthrough = KeymapResolver.resolve(keySequence: ab, keymap: keymap) {
            // Expected: a missing required argument does not create a binding.
        } else {
            XCTFail("A binding with missing required arguments should be ignored")
        }
        if case .action(let action) = KeymapResolver.resolve(keySequence: cd, keymap: keymap) {
            XCTAssertTrue(action is DirectModeAction)
        } else {
            XCTFail("The first duplicate binding should be retained")
        }
    }

    func testDeclarativeTopLevelActionBindings() {
        let keymap = Keymap("test-top-level-actions")
        applyTopLevelActionBindings([
            UserConfigs.ActionBindingConfig(keys: "space", action: "emitPending", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "escape", action: "resetAllState", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "delete", action: "removeLastPending", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "-", action: "removeLastPending", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "-", action: "emitPending", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "xy", action: "emitPending", inflection: nil, text: nil),
            UserConfigs.ActionBindingConfig(keys: "x", action: "unknown", inflection: nil, text: nil)
        ], to: keymap)

        if case .action(let action) = keymap.lookup(input: InputEvent(type: .space, text: " ")) {
            XCTAssertTrue(action is EmitPendingAction)
        } else {
            XCTFail("space should resolve to EmitPendingAction")
        }
        if case .action(let action) = keymap.lookup(input: InputEvent(type: .escape, text: "\u{1b}")) {
            XCTAssertTrue(action is ResetAllStateAction)
        } else {
            XCTFail("escape should resolve to ResetAllStateAction")
        }
        if case .action(let action) = keymap.lookup(input: InputEvent(type: .delete, text: "\u{08}")) {
            XCTAssertTrue(action is RemoveLastPendingAction)
        } else {
            XCTFail("delete should resolve to RemoveLastPendingAction")
        }
        if case .action(let action) = keymap.lookup(input: InputEvent(type: .printable, text: "-")) {
            XCTAssertTrue(action is RemoveLastPendingAction)
        } else {
            XCTFail("a one-character printable binding should be applied")
        }
        XCTAssertNil(keymap.lookup(input: InputEvent(type: .printable, text: "x")))
    }
}
