//
//  RecentTextClient.swift
//  MacTcode
//
//  Created by maeda on 2024/06/02.
//

import Cocoa

/// 最近入力した文字を保存しておくClient
class RecentTextClient: Client {
    var maxLength: Int = 20
    var text: String
    init(_ string: String, _ maxLength: Int = UserConfigs.shared.system.recentTextMaxLength) {
        self.text = string
        self.maxLength = maxLength
    }
    func bundleId() -> String! {
        return "jp.mad-p.inputmethod.MacTcode.recentTextClient"
    }
    func selectedRange() -> NSRange {
        return NSRange(location: text.count, length: 0)
    }
    // rangeは文字数で数える(text.indexではない)
    func string(
        from range: NSRange,
        actualRange: NSRangePointer
    ) -> String! {
        Log.i("RecentTextClient.string(\(range))")
        var s = range.location
        if s < 0 {
            s = 0
        }
        var l = range.length
        if s + l > text.count {
            l = text.count - s
        }
        if l < 0 {
            l = 0
        }
        Log.i("  getting substring(\(s),\(l)) from \(text)")
        let from = text.index(text.startIndex, offsetBy: s)
        let to = text.index(from, offsetBy: l)
        actualRange.pointee.location = s
        actualRange.pointee.length = l
        return String(text[from..<to])
    }
    func insertText(
        _ newString: String,
        replacementRange rr: NSRange
    ) {
        if rr.location == NSNotFound {
            text.append(newString)
        } else {
            let from = text.index(text.startIndex, offsetBy: rr.location)
            let to = if rr.length == NSNotFound {
                text.endIndex
            } else {
                text.index(from, offsetBy: rr.length)
            }
            Log.i("RecentTextClient insertText(newString=\(newString), rr=\(rr))")
            text.replaceSubrange(from..<to, with: newString)
        }
        trim()
    }
    func trim() {
        let m = maxLength
        if text.count > m {
            let newStart = text.index(text.endIndex, offsetBy: -m)
            text.replaceSubrange(text.startIndex..<newStart, with: "")
        }
    }
    func sendBackspace() {
        if text.count > 0 {
            text.removeLast()
        }
    }
    func append(_ newString: String) {
        text.append(newString)
        trim()
    }
    func replaceLast(length: Int, with newString: String) {
        let start = text.index(text.endIndex, offsetBy: -length)
        text.replaceSubrange(start..<text.endIndex, with: newString)
    }
}
