//
//  MazegakiSelectionTests.swift
//  MacTcodeTests
//
//  Created by maeda on 2024/06/08.
//


import XCTest
import Cocoa
import InputMethodKit
@testable import MacTcode

final class MazegakiSelectionTests: XCTestCase {
    var spy: RecentTextClient!
    var client: ContextClient!
    var controller: ControllerSpy!
    
    class CandidateWindowSpy: IMKCandidates {
        var events: [NSEvent] = []
        var shown: Bool = false
        override func setSelectionKeys(_ keyCodes: [Any]!) {
        }
        override func interpretKeyEvents(_ eventArray: [NSEvent]) {
            events = events + eventArray
        }
        override func show() {
            shown = true
        }
        override func show(_ locationHint: IMKCandidatesLocationHint) {
            shown = true
        }
        override func hide() {
            shown = false
        }
    }
    
    class ControllerSpy: Controller {
        func setBackspaceIgnore(_ count: Int) {}
        var pendingKakutei: MacTcode.PendingKakuteiMode?
        func setPendingKakutei(_ pending: MacTcode.PendingKakuteiMode?) {}
        
        var client: ContextClient
        var modeStack: [Mode]
        var mode: Mode { get { modeStack.first! } }
        var candidateWindow: IMKCandidates { get { window } }
        var window: CandidateWindowSpy = CandidateWindowSpy()
        init(mode: Mode, client: ContextClient) {
            modeStack = [mode]
            self.client = client
        }
        func pushMode(_ mode: Mode) {
            modeStack = [mode] + modeStack
        }
        func popMode() {
            modeStack.removeFirst()
        }
        func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
            if let client = sender as? ContextClient {
                self.client = client
            } else {
                XCTFail()
            }
            let inputEvent = Translator.translate(event: event)
            return mode.handle(inputEvent, client: client, controller: self)
        }
        
        func candidates(_ sender: Any!) -> [Any]! {
            if let modeWithCandidates = mode as? ModeWithCandidates {
                return modeWithCandidates.candidates(sender)
            } else {
                XCTFail()
                return []
            }
        }
        
        func candidateSelected(_ candidateString: NSAttributedString!) {
            if let modeWithCandidates = mode as? ModeWithCandidates {
                modeWithCandidates.candidateSelected(candidateString, client: client)
            } else {
                XCTFail()
            }
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
            let ret = controller.mode.handle(event, client: client, controller: controller)
            XCTAssertTrue(ret)
        }
    }
    
    override func setUpWithError() throws {
        super.setUp()
        spy = RecentTextClient("")
        client = ContextClient(client: spy, recent: RecentTextClient(""))
        controller = ControllerSpy(mode: TcodeMode(), client: client)
        Log.i("setUp!")
    }
    
    override func tearDownWithError() throws {
        super.tearDown()
    }
 
    func testWindowCreation() {
        XCTAssertFalse(controller.window.shown)
        feed("fusxfez,uh")
        XCTAssertTrue(controller.window.shown)
        XCTAssertEqual("あそう作", spy.text)
    }
    
    func testCandidates() {
        XCTAssertFalse(controller.window.shown)
        feed("fusxfez,uh")
        if let cands = controller.candidates(controller) as? [String] {
            XCTAssertEqual(["創作", "操作"].sorted(), cands.sorted())
        } else {
            XCTFail("candidates returns nil")
        }
    }
    func testForwarding() {
        XCTAssertFalse(controller.window.shown)
        feed("fusxfez,uh")
        // case 38: .enter
        // case 123: .left
        // case 124: .right
        // case 125: .down
        // case 126: .up
        // case 51: .delete
        let events: [NSEvent] = [
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 124)!,
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 38)!,
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "h", charactersIgnoringModifiers: "h", isARepeat: false, keyCode: UInt16(kVK_ANSI_J))!
        ]
        events.forEach { event in
            XCTAssertTrue(controller.handle(event, client: client))
        }
        XCTAssertEqual(events[0].keyCode, controller.window.events[0].keyCode)
        XCTAssertEqual(events[1].keyCode, controller.window.events[1].keyCode)
        XCTAssertEqual(events[2].keyCode, controller.window.events[2].keyCode)
    }
    func testKakutei() {
        XCTAssertFalse(controller.window.shown)
        feed("fusxfez,uh")
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 124)!
        _ = controller.handle(event, client: client)
        let selected: NSAttributedString = NSAttributedString(string: "操作")
        controller.candidateSelected(selected)
        XCTAssertFalse(controller.window.shown)
        XCTAssertEqual("あ操作", spy.text)
        XCTAssertEqual(1, controller.modeStack.count)
    }
}
