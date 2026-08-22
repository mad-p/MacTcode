//
//  TopLevelMap.swift
//  MacTcode
//
//  Created by maeda on 2024/05/26.
//

import Foundation

private func defaultTopLevelActionBindings() -> [UserConfigs.ActionBindingConfig] {
    [
        .init(keys: "space", action: "emitPending", inflection: nil, text: nil),
        .init(keys: "escape", action: "resetAllState", inflection: nil, text: nil),
        .init(keys: "delete", action: "removeLastPending", inflection: nil, text: nil),
        .init(keys: "-", action: "removeLastPending", inflection: nil, text: nil)
    ]
}

func topLevelInputEvent(for keys: String) -> InputEvent? {
    switch keys {
    case "space":
        return InputEvent(type: .space, text: " ")
    case "escape":
        return InputEvent(type: .escape, text: "\u{1b}")
    case "delete":
        return InputEvent(type: .delete, text: "\u{08}")
    default:
        guard keys.count == 1 else {
            return nil
        }
        return InputEvent(type: .printable, text: keys)
    }
}

func topLevelCommand(for binding: UserConfigs.ActionBindingConfig) -> Command? {
    switch binding.action {
    case "emitPending":
        return .action(EmitPendingAction())
    case "resetAllState":
        return .action(ResetAllStateAction())
    case "removeLastPending":
        return .action(RemoveLastPendingAction())
    default:
        return nil
    }
}

func applyTopLevelActionBindings(_ bindings: [UserConfigs.ActionBindingConfig], to keymap: Keymap) {
    var definedEvents = Set<InputEvent>()
    for (index, binding) in bindings.enumerated() {
        guard let event = topLevelInputEvent(for: binding.keys) else {
            Log.i("Invalid key binding at keyBindings.topLevelActions[\(index)]: keys must be a single character or one of space, escape, delete. The binding was ignored.")
            continue
        }
        guard let command = topLevelCommand(for: binding) else {
            Log.i("Invalid key binding at keyBindings.topLevelActions[\(index)]: action \(binding.action) is unknown. The binding was ignored.")
            continue
        }
        guard definedEvents.insert(event).inserted else {
            Log.i("Invalid key binding at keyBindings.topLevelActions[\(index)]: key \(binding.keys) is defined more than once. The binding was ignored.")
            continue
        }
        keymap.replace(input: event, entry: command)
    }
}

private func buildTopLevelMap() -> Keymap {
    let map = Keymap("TopLevelMap")
    let bindings = UserConfigs.i.keyBindings.topLevelActions ?? defaultTopLevelActionBindings()
    applyTopLevelActionBindings(bindings, to: map)
    return map
}

class TopLevelMap {
    static var map: Keymap = buildTopLevelMap()

    static func reloadKeymap() {
        map = buildTopLevelMap()
        Log.i("Top-level keymap reloaded from UserConfigs")
    }
}
