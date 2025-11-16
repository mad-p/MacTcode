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
    var modeStack: [Mode] = []
    let candidateWindow: IMKCandidates
    var pendingKakutei: PendingKakuteiMode?
    var backspaceIgnore = 0
   
    func setBackspaceIgnore(_ count: Int) {
        self.backspaceIgnore += count
        Log.i("Expecting \(backspaceIgnore) backspaces to be ignored")
    }

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        candidateWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
        setupCandidateWindow()
        Log.i("★★TcodeInputController: init self=\(ObjectIdentifier(self))")
    }

    override func inputControllerWillClose() {
        Log.i("★★TcodeInputController: inputControllerWillClose self=\(ObjectIdentifier(self))")
        super.inputControllerWillClose()
    }
    
    override func deactivateServer(_ sender: Any!) {
        Log.i("★deactivate")
        // deactivate時にpendingKakuteiがあれば受容する
        if let pending = mode as? PendingKakuteiMode {
            Log.i("deactivate: accepting pendingKakutei")
            pending.accept()
        }
        InputStats.shared.writeStatsToFileMaybe()
        super.deactivateServer(sender)
    }
    
    func setupCandidateWindow() {
        // UserConfigsから候補選択キーを取得してVirtual Key Codeに変換
        let configKeys = UserConfigs.shared.ui.candidateSelectionKeys
        let keyMap: [String: Int] = [
            // アルファベット a-z
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            // 数字 0-9
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            // 記号
            "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
            "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
            "'": kVK_ANSI_Quote, ";": kVK_ANSI_Semicolon,
            ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
        ]
        let selectionKeys = configKeys.compactMap { keyMap[$0] }
        candidateWindow.setSelectionKeys(selectionKeys)
    }
    
    func wrapClient() -> ContextClient {
        let textInput = self.client()!
        let bid = textInput.bundleIdentifier()
        var wrappedClient = ContextClient(client: ClientWrapper(textInput, bid), recent: nil)
        // モードごとにclientに機能を追加する
        for m in modeStack.reversed() {
            wrappedClient = m.wrapClient(wrappedClient)
        }
        return wrappedClient
    }
    
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }
        // 除外アプリケーションでは変換しないでそのまま入力する
        if modeStack.isEmpty {
            pushMode(TcodeMode(controller: self))
        }
        Log.i("handle: client=\(type(of: client))")
        Log.i("  modeStack=\(modeStack)")
        let bid = client.bundleIdentifier()
        Log.i("  client.bundleIdentifier=\(bid ?? "nil")")
        let excludedApps = UserConfigs.shared.system.excludedApplications
        let bundleId = bid
        if bundleId != nil && excludedApps.contains(bundleId!) {
            return false
        }
        let inputEvent = Translator.translate(event: event)
        let wrappedClient = wrapClient()
        Log.i("wrappedClient: \(type(of:wrappedClient))")
        // backspaceIgnoreがある間は、キャンセル用と見なさない
        if (inputEvent.type == .delete && backspaceIgnore > 0) {
            backspaceIgnore -= 1
            Log.i("Ignore Backspace. Expecting \(backspaceIgnore) more")
            return false
        }

        // 最新のモードから順にイベント処理のチャンスを与える
        for m in Array(modeStack) { // 念のためコピーしてから順に利用
            Log.i("calling mode \(type(of:m)).handle")
            let handleResult = m.handle(inputEvent, client: wrappedClient)
            Log.i(" handle returned: \(handleResult)")
            switch handleResult {
            case .forward: continue
            case .passthrough: return false
            case .processed: return true
            }
        }
        // どのモードでも処理しなかったのでクライアントにゆだねる
        return false
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
                modeWithCandidates.candidateSelected(candidateString, client: wrapClient())
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
            if modeStack.isEmpty {
                pushMode(TcodeMode(controller: self))
            }
            return modeStack.first!
        }
    }
    func pushMode(_ mode: Mode) {
        Log.i("TcodeInputController.pushMode: \(mode)")
        modeStack = [mode] + modeStack
    }
    func popMode(_ mode: Mode) {
        if let index = modeStack.firstIndex(where: { $0 === mode }) {
            modeStack.remove(at: index)
        }
    }
}
