//
//  TcodeTable.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Foundation

fileprivate func buildTcodeKeymap() -> Keymap {
    // UserConfigsから基文文字マップを取得
    let keyBindings = UserConfigs.i.keyBindings
    let basicTableString = keyBindings.basicTable.joined(separator: "\n")
    
    let map = Keymap("TCode2D", from2d: basicTableString)
    
    // UserConfigsからキーシーケンス設定を取得
    let bushuConversion = keyBindings.bushuConversion
    if bushuConversion != "" {
        KeymapResolver.define(sequence: bushuConversion, keymap: map, action: PostfixBushuAction())
    }
    let mazegakiConversion = keyBindings.mazegakiConversion
    if mazegakiConversion != "" {
        KeymapResolver.define(sequence: mazegakiConversion, keymap: map, action: PostfixMazegakiAction(inflection: false))
    }
    let inflectionConversion = keyBindings.inflectionConversion
    if inflectionConversion != "" {
        KeymapResolver.define(sequence: inflectionConversion, keymap: map, action: PostfixMazegakiAction(inflection: true))
    }
    
    // Ctrl-' → Tcode, Ctrl-, → 英数
    map.replace(input: InputEvent(type: .control_punct, text: "'"),
                entry: Command.action(TcodeModeAction()))
    map.replace(input: InputEvent(type: .control_punct, text: ","), entry: Command.action(DirectModeAction()))
    let directMode = keyBindings.directMode
    if directMode != "" {
        KeymapResolver.define(sequence: directMode, keymap: map, action: DirectModeAction())
    }
    
    // 年号入力。直接入力に変更しつつ、元のキーを入力
    KeymapResolver.define(sequence: "19", keymap: map, action: SelfInsertAndDirectMode(text: "19"))
    KeymapResolver.define(sequence: "20", keymap: map, action: SelfInsertAndDirectMode(text: "20"))
    
    // かな、英数キーはここに来るまでに処理されているはずなので無視する
    map.replace(input: InputEvent(type: .japanese, text: " "), entry: .processed)
    // passthrough Ctrl-SPC (set-mark)
    map.replace(input: InputEvent(type: .control_punct, text: " "), entry: .passthrough)
    
    let zenkakuMode = keyBindings.zenkakuMode
    if zenkakuMode != "" {
        KeymapResolver.define(sequence: zenkakuMode, keymap: map, action: ZenkakuModeAction())
    }
    let zenkakuOneMode = keyBindings.zenkakuOneMode
    if keyBindings.zenkakuOneMode != "" {
        KeymapResolver.define(sequence: zenkakuOneMode, keymap: map, action: ZenkakuOneModeAction())
    }
    let hankanaMode = keyBindings.hankanaMode
    if hankanaMode != "" {
        KeymapResolver.define(sequence: hankanaMode, keymap: map, action: HankanaModeAction())
    }
    let lineMode = keyBindings.lineMode
    if lineMode != "" {
        KeymapResolver.define(sequence: lineMode, keymap: map, action: ToggleLineModeAction())
    }
    KeymapResolver.define(sequence: keyBindings.symbolSet1, keymap: map, entry: Command.keymap(
        Keymap("outset1", fromChars: UserConfigs.i.ui.symbolSet1Chars)))
    KeymapResolver.define(sequence: keyBindings.symbolSet2, keymap: map, entry: Command.keymap(
        Keymap("outset2", fromChars: UserConfigs.i.ui.symbolSet2Chars)))
    
    return map
}

class TcodeKeymap {
    static var map: Keymap = buildTcodeKeymap()
    
    // 設定変更時にキーマップを再初期化するためのメソッド
    static func reloadKeymap() {
        map = buildTcodeKeymap()
        
        Log.i("TCode keymap reloaded from UserConfigs")
    }
}
