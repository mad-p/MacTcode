//
//  TcodeTable.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Foundation

class TcodeKeymap {
    static var map: Keymap = {
        // UserConfigsから基文文字マップを取得
        let keyBindings = UserConfigs.shared.keyBindings
        let basicTableString = keyBindings.basicTable.joined(separator: "\n")
        
        let map = Keymap("TCode2D", from2d: basicTableString)
        
        // UserConfigsからキーシーケンス設定を取得
        KeymapResolver.define(sequence: keyBindings.bushuConversion, keymap: map, action: PostfixBushuAction())
        KeymapResolver.define(sequence: keyBindings.mazegakiConversion, keymap: map, action: PostfixMazegakiAction(inflection: false))
        KeymapResolver.define(sequence: keyBindings.inflectionConversion, keymap: map, action: PostfixMazegakiAction(inflection: true))
        
        // ignore Ctrl-'
        map.replace(input: InputEvent(type: .control_punct, text: ","), entry: .processed)
        // passthrough Ctrl-SPC (set-mark)
        map.replace(input: InputEvent(type: .control_punct, text: " "), entry: .passthrough)
        
        KeymapResolver.define(sequence: keyBindings.zenkakuMode, keymap: map, action: ZenkakuModeAction())
        KeymapResolver.define(sequence: keyBindings.symbolSet1, keymap: map, entry: Command.keymap(
            Keymap("outset1", fromChars: "√∂『』　\"《》【】┏┳┓┃◎◆■●▲▼┣╋┫━　◇□○△▽┗┻┛／＼※§¶†‡")))
        KeymapResolver.define(sequence: keyBindings.symbolSet2, keymap: map, entry: Command.keymap(
            Keymap("outset2", fromChars: "♠♡♢♣㌧㊤㊥㊦㊧㊨㉖㉗㉘㉙㉚⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳①②③④⑤㉑㉒㉓㉔㉕⑥⑦⑧⑨⑩")))
        
        return map
    }()
    
    // 設定変更時にキーマップを再初期化するためのメソッド
    static func reloadKeymap() {
        map = {
            let keyBindings = UserConfigs.shared.keyBindings
            let basicTableString = keyBindings.basicTable.joined(separator: "\n")
            
            let newMap = Keymap("TCode2D", from2d: basicTableString)
            
            KeymapResolver.define(sequence: keyBindings.bushuConversion, keymap: newMap, action: PostfixBushuAction())
            KeymapResolver.define(sequence: keyBindings.mazegakiConversion, keymap: newMap, action: PostfixMazegakiAction(inflection: false))
            KeymapResolver.define(sequence: keyBindings.inflectionConversion, keymap: newMap, action: PostfixMazegakiAction(inflection: true))
            
            newMap.replace(input: InputEvent(type: .control_punct, text: ","), entry: .processed)
            newMap.replace(input: InputEvent(type: .control_punct, text: " "), entry: .passthrough)
            
            KeymapResolver.define(sequence: keyBindings.zenkakuMode, keymap: newMap, action: ZenkakuModeAction())
            KeymapResolver.define(sequence: keyBindings.symbolSet1, keymap: newMap, entry: Command.keymap(
                Keymap("outset1", fromChars: "√∂『』　\"《》【】┏┳┓┃◎◆■●▲▼┣╋┫━　◇□○△▽┗┻┛／＼※§¶†‡")))
            KeymapResolver.define(sequence: keyBindings.symbolSet2, keymap: newMap, entry: Command.keymap(
                Keymap("outset2", fromChars: "♠♡♢♣㌧㊤㊥㊦㊧㊨㉖㉗㉘㉙㉚⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳①②③④⑤㉑㉒㉓㉔㉕⑥⑦⑧⑨⑩")))
            
            return newMap
        }()
        
        Log.i("TCode keymap reloaded from UserConfigs")
    }
}