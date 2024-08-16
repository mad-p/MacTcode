//
//  ZenkakuMode.swift
//  MacTcode
//
//  Created by maeda on 2024/06/05.
//

import Cocoa

/// 全角入力モード
class ZenkakuMode: Mode {
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
    
    func handle(_ inputEvent: InputEvent, client: ContextClient!, controller: Controller) -> Bool {
        switch inputEvent.type {
        case .printable:
            if let inputString = inputEvent.text {
                let string = han2zen(inputString)
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return true
            }
            return false
        case .escape:
            controller.popMode()
            return true
        default:
            return false
        }
    }
    
    func reset() {
        
    }
}

