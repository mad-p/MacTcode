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

                // ここでストローク統計を記録
                // 基本キー2打鍵で入力された場合に限り、統計情報を記録する
                // NOTE: バックスラッシュによる記号入力は2打鍵でも基本キー以外も使うので除外
                // NOTE: 3ストローク以上に対応するときは修正が必要
                if seq.count == 2 {
                    if let ev0 = seq[0].text, let ev1 = seq[1].text,
                       let k1 = Translator.strToKey(ev0), let k2 = Translator.strToKey(ev1) {
                        InputStats.i.recordBasicStroke(key1: k1, key2: k2)
                        InputStats.i.recordStroke(key: k1)
                        InputStats.i.recordStroke(key: k2)
                    }
                }

                // 自動部首変換を試みる
                if Bushu.i.tryAutoBushu(client: client, controller: controller!) {
                    InputStats.i.incrementBushuCount()
                    InputStats.i.recordKakutei(charCount: 1, subtract: 2)
                } else {
                    InputStats.i.incrementBasicCount()
                    InputStats.i.recordKakutei(charCount: 1)
                }
                return .processed
            case .action(let action):
                InputStats.i.incrementFunctionCount()
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
