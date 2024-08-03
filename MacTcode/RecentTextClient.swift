//
//  RecentText.swift
//  MacTcode
//
//  Created by maeda on 2024/06/02.
//

import Cocoa

class RecentTextClient: Client {
    var maxLength: Int = 20
    var text: String
    init(_ string: String, _ maxLengeth: Int = 20) {
        self.text = string
        self.maxLength = maxLengeth
    }
    func selectedRange() -> NSRange {
        return NSRange(location: text.count, length: 0)
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer
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

/// クライアントのカーソル周辺の文字列、もし得られなければrecentCharsを扱うMyInputText
/// clientをMyInputTextにしておくことで、テストのときにclientをspyとして使える
class MirroringClient: Client {
    let client: Client
    let recent: RecentTextClient
    let target: Client
    let useRecent: Bool
    init(client: Client, recent: RecentTextClient) {
        self.client = client
        self.recent = recent
        let cursor = client.selectedRange()
        Log.i("MirroringClient: client returned cursor = \(cursor)")
        if cursor.location == NSNotFound {
            Log.i("MirroringClient uses recent")
            (target, useRecent) = (recent, true)
        } else {
            Log.i("MirroringClient uses client")
            (target, useRecent) = (client, false)
        }
    }
    func selectedRange() -> NSRange {
        return target.selectedRange()
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer
    ) -> String! {
        return target.string(from: range, actualRange: actualRange)
    }
    func insertText(
        _ string: String,
        replacementRange rr: NSRange
    ) {
        if useRecent {
            // replacementRangeが使えそうにないclientの場合は、BackSpaceを送ってから文字列を送る
            if rr.length != NSNotFound && rr.length < 10 {
                Log.i("Sending \(rr.length) BackSpaces and then \(string)")
                let now = DispatchTime.now()
                for i in 0..<rr.length {
                    DispatchQueue.main.asyncAfter(deadline: now + 0.05 * Double(i)) {
                        self.client.sendBackspace()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: now + 0.05 * Double(rr.length)) {
                    self.client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                }
            } else {
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                recent.insertText(string, replacementRange: rr)
            }
        } else {
            client.insertText(string, replacementRange: rr)
            if rr.length == NSNotFound {
                recent.append(string)
            } else {
                recent.replaceLast(length: rr.length, with: string)
            }
        }
    }
    func sendBackspace() {
        target.sendBackspace()
    }
}
