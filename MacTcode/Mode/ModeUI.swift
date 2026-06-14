//
//  ModeUI.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2026/06/14.
//

class InputModeId {
    static let tcode = "com.apple.inputmethod.Japanese"
    static let direct = "com.apple.inputmethod.Roman"
    static let hankana = "com.apple.inputmethod.Japanese.HalfWidthKana"
    static let zenkaku = "com.apple.inputmethod.Japanese.FullWidthRoman"
    
    static func idToInputMode(_ id: String) -> InputMode {
        switch id {
        case InputModeId.tcode:
            return .tcode
        case InputModeId.direct:
            return .direct
        case InputModeId.hankana:
            return .hankana
        case InputModeId.zenkaku:
            return .zenkaku
        default:
            return .direct
        }
    }
    static func inputModeToId(_ mode: InputMode) -> String {
        switch mode {
        case .tcode:
            return InputModeId.tcode
        case .direct:
            return InputModeId.direct
        case .hankana:
            return InputModeId.hankana
        case .zenkaku:
            return InputModeId.zenkaku
        }
    }
}

enum InputMode {
    case direct
    case tcode
    case hankana
    case zenkaku
}
