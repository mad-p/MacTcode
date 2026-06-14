//
//  ZenkakuMode.swift
//  MacTcode
//
//  Created by maeda on 2024/06/05.
//

import Cocoa

/// 全角モードの設定
enum ZenkakuModeSetting {
    case multi
    case single
}

/// 全角入力モード
class ZenkakuMode: Mode {
    weak var controller: Controller?
    var setting: ZenkakuModeSetting
    init(controller: Controller, setting: ZenkakuModeSetting = .multi) {
        self.controller = controller
        self.setting = setting
    }
    func setController(_ controller: Controller) {
        self.controller = controller
    }
    
    func wrapClient(_ client: ContextClient!) -> ContextClient! {
        return client
    }
    
    static let zenkaku = {
        return "　！”＃＄％＆’（）＊＋，−．／０１２３４５６７８９：；＜＝＞？＠ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ［￥］＾＿‘ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ｛｜｝￣"
            .map{ String($0) }
    }()
    
    func han2zen(_ string: String) -> String {
        return string.map { ch in
            if let ascii = ch.asciiValue {
                if (0x20..<0x7f).contains(ascii) {
                    ZenkakuMode.zenkaku[Int(ascii - 0x20)]
                } else {
                    String(ch)
                }
            } else {
                String(ch)
            }
        }.joined()
    }
    
    func handle(_ inputEvent: InputEvent, client: ContextClient!) -> HandleResult {
        switch inputEvent.type {
        case .printable:
            if let inputString = inputEvent.text {
                let string = han2zen(inputString)
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                if setting == .single {
                    reset()
                }
                return .processed
            }
            return .forward
        case .escape, .enter:
            reset()
            return .processed
        case .space:
            if setting == .single {
                client.insertText(UserConfigs.i.keyBindings.zenkakuOneMode, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                reset()
            } else {
                client.insertText("　", replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
            return .processed
        default:
            return .forward
        }
    }
    
    func reset() {
        controller?.popMode(self)
        controller?.setInputMode(.tcode)
    }
}

