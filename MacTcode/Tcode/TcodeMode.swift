//
//  TcodeMode.swift
//  MacTcode
//
//  Created by maeda on 2024/08/05.
//

import Cocoa
import InputMethodKit

class TcodeMode: Mode, MultiStroke {
    weak var controller: Controller?
    var pending: [InputEvent] = []
    let recentText = RecentTextClient("")
    var map = TcodeKeymap.map
    var quickMap: Keymap = TopLevelMap.map
    func setController(_ controller: any Controller) {
        self.controller = controller
    }
    func wrapClient(_ client: ContextClient!) -> ContextClient! {
        return ContextClient(client: client, recent: recentText)
    }
    func resetPending() {
        pending = []
    }
    func reset() {
        resetPending()
    }
    func removeLastPending() {
        if pending.count > 0 {
            pending.removeLast()
        }
    }
    func handle(_ inputEvent: InputEvent, client: ContextClient!) -> HandleResult {
        let seq = pending + [inputEvent]
        
        // 複数キーからなるキーシーケンスの途中でも処理するコマンドはquickMapに入れておく
        // - spaceでpendingを送る
        // - escapeで取り消す
        // - deleteで1文字消す
        var fromTopLevel = false
        var command: Command
        if let topLevelEntry = quickMap.lookup(input: inputEvent) {
            fromTopLevel = true
            command = topLevelEntry
        } else {
            fromTopLevel = false
            command = KeymapResolver.resolve(keySequence: seq, keymap: map)
        }
        while true {
            Log.i("execute command \(command)")
            
            switch command {
            case .passthrough:
                if fromTopLevel {
                    command = KeymapResolver.resolve(keySequence: seq, keymap: map)
                    fromTopLevel = false
                    continue
                }
                resetPending()
                return .passthrough
            case .processed:
                resetPending()
                return .processed
            case .pending:
                pending = seq
                client.sendDummyInsertMaybe()
                return .processed
            case .text(let string):
                resetPending()
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))

                // 自動部首変換を試みる
                if Bushu.i.tryAutoBushu(client: client, controller: controller!) {
                    InputStats.shared.incrementBushuCount()
                } else {
                    InputStats.shared.incrementBasicCount()
                }
                return .processed
            case .action(let action):
                InputStats.shared.incrementFunctionCount()
                command = action.execute(client: client, mode: self, controller: controller!)
                resetPending()
                continue
            case .keymap(_):
                Log.i("★Keymap resolved to .keymap??")
                return .processed
            }
        }
    }
}
