//
//  TcodeInputController.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Cocoa
import InputMethodKit

@objc(TcodeInputController)
class TcodeInputController: IMKInputController, Controller {
    var modeStack: [Mode]
    let candidateWindow: IMKCandidates
    let recentText = RecentTextClient("")
    
    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        modeStack = [TcodeMode()]
        candidateWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
        setupCandidateWindow()
        Log.i("★★TcodeInputController: init self=\(ObjectIdentifier(self))")
    }

    override func inputControllerWillClose() {
        Log.i("★★TcodeInputController: inputControllerWillClose self=\(ObjectIdentifier(self))")
        super.inputControllerWillClose()
    }
    
    func setupCandidateWindow() {
        let selectionKeys = [
            kVK_ANSI_J,
            kVK_ANSI_K,
            kVK_ANSI_L,
            kVK_ANSI_Semicolon,
            kVK_ANSI_1,
            kVK_ANSI_2,
            kVK_ANSI_3,
            kVK_ANSI_4,
            kVK_ANSI_5,
            kVK_ANSI_6,
            kVK_ANSI_7,
            kVK_ANSI_8,
            kVK_ANSI_9,
            kVK_ANSI_0,
        ]
        candidateWindow.setSelectionKeys(selectionKeys)
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        // ログイン画面では変換しないでそのまま入力する
        Log.i("handle: client=\(type(of: client))")
        let bid = client.bundleIdentifier()
        Log.i("  client.bundleIdentifier=\(bid ?? "nil")")
        if bid == "com.apple.loginwindow" {
            return false
        }
        let inputEvent = Translator.translate(event: event)
        let baseInputText = MirroringClient(client: ClientWrapper(client), recent: recentText)
        return mode.handle(inputEvent, client: baseInputText, controller: self)
    }
    
    override func candidates(_ sender: Any!) -> [Any]! {
        if let modeWithCandidates = mode as? ModeWithCandidates {
            let ret = modeWithCandidates.candidates(sender)
            Log.i("TcodeInputController.candidates: returns \(ret!)")
            return ret
        } else {
            Log.i("*** TcodeInputController.candidates: called for non-ModeWithCandidates???")
            return []
        }
    }
    
    override func candidateSelected(_ candidateString: NSAttributedString!) {
        Log.i("TcodeInputController.candidateSelected: \(candidateString.string)")
        if let modeWithCandidates = mode as? ModeWithCandidates {
            if let client = self.client() {
                let baseInputText = MirroringClient(client: ClientWrapper(client), recent: recentText)
                modeWithCandidates.candidateSelected(candidateString, client: baseInputText)
            } else {
                Log.i("*** TcodeInputController.candidateSelected: client is not IMKTextInput???")
            }
        } else {
            Log.i("*** TcodeInputController.candidateSelected: called for non-ModeWithCandidates???")
        }
    }
    
    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        Log.i("TcodeInputController.candidateSelectionChanged: \(candidateString.string)")
        if let modeWithCandidates = mode as? ModeWithCandidates {
            modeWithCandidates.candidateSelectionChanged(candidateString)
        } else {
            Log.i("*** TcodeInputController.candidates: called for non-ModeWithCandidates???")
        }
    }
 
    var mode: Mode {
        get {
            modeStack.first!
        }
    }
    func pushMode(_ mode: Mode) {
        Log.i("TcodeInputController.pushMode: \(mode)")
        modeStack = [mode] + modeStack
    }
    func popMode() {
        if modeStack.count > 1 {
            modeStack.removeFirst()
        }
    }
}
