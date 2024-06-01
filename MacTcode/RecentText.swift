//
//  RecentText.swift
//  MacTcode
//
//  Created by maeda on 2024/06/02.
//

import Cocoa

class RecentText: MyInputText {
    static let maxLength: Int = 20
    var text: String
    init(_ string: String) {
        self.text = string
    }
    func selectedRange() -> NSRange {
        return NSRange(location: text.count, length: 0)
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer!
    ) -> String! {
        var s = range.location
        if s < 0 {
            s = 0
        }
        var l = range.length
        if s + l > text.count {
            l = text.count - s
        }
        let from = text.index(text.startIndex, offsetBy: s)
        let to = text.index(from, offsetBy: l)
        actualRange.pointee.location = s
        actualRange.pointee.length = l
        return String(text[from..<to])
    }
    func insertText(
        _ newString: String!,
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
            text.replaceSubrange(from..<to, with: newString)
        }
        trim()
    }
    func trim() {
        let m = RecentText.maxLength
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
}
