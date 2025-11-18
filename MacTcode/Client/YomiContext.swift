//
//  YomiContext.swift
//  MacTcode
//
//  Created by maeda on 2024/08/15.
//

import Cocoa

/// Clientからカーソル直前の数文字を取得した結果
class YomiContext {
    let string: String
    let range: NSRange
    let fromSelection: Bool
    let fromMirror: Bool
    
    init(string: String, range: NSRange, fromSelection: Bool, fromMirror: Bool) {
        self.string = string
        self.range = range
        self.fromSelection = fromSelection
        self.fromMirror = fromMirror
        // Log.i("YomiContext: string=\(string), range=\(range), fromSelection: \(fromSelection), fromMirror: \(fromMirror)")
    }
}
