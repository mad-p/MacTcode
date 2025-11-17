//
//  ControllerSpy.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2025/11/17.
//

import XCTest
import Cocoa
import InputMethodKit
@testable import MacTcode

class ControllerSpy: Controller {
    var modeStack: [Mode] = []
    func setBackspaceIgnore(_ count: Int) {}
    var candidateWindow: IMKCandidates = IMKCandidates() // dummy
    var mode: Mode {
        get {
            if modeStack.isEmpty {
                pushMode(TcodeMode())
            }
            return modeStack.first!
        }
    }
    func pushMode(_ mode: Mode) {
        modeStack = [mode]
        mode.setController(self)
    }
    func popMode(_ mode: Mode) {
        if let index = modeStack.firstIndex(where: { $0 === mode }) {
            modeStack.remove(at: index)
        }
    }
}
