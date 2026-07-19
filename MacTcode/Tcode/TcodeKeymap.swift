//
//  TcodeTable.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Foundation

private func legacyActionBindings(from keyBindings: UserConfigs.KeyBindingsConfig) -> [UserConfigs.ActionBindingConfig] {
    [
        (keyBindings.bushuConversion, "postfixBushu", nil, nil),
        (keyBindings.mazegakiConversion, "postfixMazegaki", false, nil),
        (keyBindings.inflectionConversion, "postfixMazegaki", true, nil),
        (keyBindings.directMode, "directMode", nil, nil),
        ("19", "selfInsertAndDirectMode", nil, "19"),
        ("20", "selfInsertAndDirectMode", nil, "20"),
        (keyBindings.zenkakuMode, "zenkakuMode", nil, nil),
        (keyBindings.zenkakuOneMode, "zenkakuOneMode", nil, nil),
        (keyBindings.hankanaMode, "hankanaMode", nil, nil),
        (keyBindings.lineMode, "lineMode", nil, nil),
        (keyBindings.symbolSet1, "symbolSet1", nil, nil),
        (keyBindings.symbolSet2, "symbolSet2", nil, nil),
        ("C-'", "tcodeMode", nil, nil),
        ("C-,", "directMode", nil, nil),
    ].compactMap { keys, action, inflection, text in
        keys.isEmpty ? nil : UserConfigs.ActionBindingConfig(
            keys: keys, action: action, inflection: inflection, text: text
        )
    }
}

func command(for binding: UserConfigs.ActionBindingConfig, ui: UserConfigs.UIConfig) -> Command? {
    switch binding.action {
    case "postfixBushu":
        return .action(PostfixBushuAction())
    case "postfixMazegaki":
        return .action(PostfixMazegakiAction(inflection: binding.inflection ?? false))
    case "zenkakuMode":
        return .action(ZenkakuModeAction())
    case "zenkakuOneMode":
        return .action(ZenkakuOneModeAction())
    case "hankanaMode":
        return .action(HankanaModeAction())
    case "lineMode":
        return .action(ToggleLineModeAction())
    case "tcodeMode":
        return .action(TcodeModeAction())
    case "directMode":
        return .action(DirectModeAction())
    case "selfInsertAndDirectMode":
        guard let text = binding.text, !text.isEmpty else {
            return nil
        }
        return .action(SelfInsertAndDirectMode(text: text))
    case "symbolSet1":
        guard let keymap = Keymap("outset1", fromChars: ui.symbolSet1Chars) else {
            return nil
        }
        return .keymap(keymap)
    case "symbolSet2":
        guard let keymap = Keymap("outset2", fromChars: ui.symbolSet2Chars) else {
            return nil
        }
        return .keymap(keymap)
    default:
        return nil
    }
}

func applyActionBindings(_ bindings: [UserConfigs.ActionBindingConfig], to keymap: Keymap, ui: UserConfigs.UIConfig) {
    var definedSequences = Set<String>()
    for (index, binding) in bindings.enumerated() {
        guard !binding.keys.isEmpty else {
            NSLog("Invalid key binding at keyBindings.actions[%d]: keys must not be empty. The binding was ignored.", index)
            continue
        }
        guard let entry = command(for: binding, ui: ui) else {
            NSLog("Invalid key binding at keyBindings.actions[%d]: action %@ has invalid or missing arguments. The binding was ignored.", index, binding.action)
            continue
        }
        guard definedSequences.insert(binding.keys).inserted else {
            NSLog("Invalid key binding at keyBindings.actions[%d]: sequence %@ is defined more than once. The binding was ignored.", index, binding.keys)
            continue
        }
        KeymapResolver.define(sequence: binding.keys, keymap: keymap, entry: entry)
    }
}

fileprivate func buildTcodeKeymap() -> Keymap {
    // UserConfigsから基文文字マップを取得
    let keyBindings = UserConfigs.i.keyBindings
    let basicTableString = keyBindings.basicTable.joined(separator: "\n")
    
    let map = Keymap("TCode2D", from2d: basicTableString)
    
    // かな、英数キーはここに来るまでに処理されているはずなので無視する
    map.replace(input: InputEvent(type: .japanese, text: " "), entry: .processed)
    // passthrough Ctrl-SPC (set-mark)
    map.replace(input: InputEvent(type: .control_punct, text: " "), entry: .passthrough)
    
    // actions が未指定なら、移行期間中は旧形式の個別設定を使用する。
    let bindings = keyBindings.actions ?? legacyActionBindings(from: keyBindings)
    applyActionBindings(bindings, to: map, ui: UserConfigs.i.ui)
    
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
