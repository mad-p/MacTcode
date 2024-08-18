//
//  ContextClient.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Cocoa

/// 部首変換、交ぜ書き変換への入力を取得するためのClient
/// クライアントのカーソル周辺の文字列、もし得られなければRecentTextClientから取るClient
class ContextClient: Client {
    var client: Client
    let recent: RecentTextClient
    var lastCursor: NSRange = NSRange(location: NSNotFound, length: NSNotFound)
    init(client: Client, recent: RecentTextClient) {
        self.client = client
        self.recent = recent
    }
    func selectedRange() -> NSRange {
        Log.i("★★Can't happen.  ContextClient.selectedRange()")
        return client.selectedRange()
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer
    ) -> String! {
        Log.i("★★Can't happen.  ContextClient.string(from:actualRange:)")
        return client.string(from: range, actualRange: actualRange)
    }
    func insertText(
        _ string: String,
        replacementRange rr: NSRange
    ) {
        client.insertText(string, replacementRange: rr)
        if rr.length == NSNotFound {
            recent.append(string)
        } else {
            Log.i("★★Can't happen.  ContextClient.insertText with range?")
            recent.replaceLast(length: rr.length, with: string)
        }
    }
    func sendBackspace() {
        Log.i("★★Can't happen. ContextClient.sendBackspace()")
        client.sendBackspace()
    }
    // カーソル直前にある読みを取得する
    // クライアントが対応していなければrecentから取る
    func getYomi(_ minLength: Int, _ maxLength: Int) -> YomiContext {
        let cursor = client.selectedRange()
        lastCursor = cursor
        Log.i("getYomi: cursor=\(cursor) minLength=\(minLength) maxLength=\(maxLength)")
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)
        var location: Int
        var getLength = minLength
        var fromSelection: Bool
        var fromMirror: Bool
        let emptyYomiContext = YomiContext(string: "", range: cursor, fromSelection: true, fromMirror: false)
        // 選択がある場合 → 選択全体
        // 選択がない場合
        //  カーソルの前に文字がある場合
        //     min, maxの指定を満たす場合 → 取れるだけ取る
        //     満たさない場合 →
        //  カーソルの前に文字がない場合 → ミラーから
        if cursor.location == NSNotFound {
            // カーソルが取得できないクライアント
            location = 0
            getLength = 0
            fromMirror = true
            fromSelection = false
            Log.i("No cursor. Using mirror")
            // fall through to get from mirror
        } else if (cursor.length != 0 && cursor.length != NSNotFound) { // cursor.location != NSNotFound
            // 選択がある
            if minLength == maxLength {
                // min = maxの場合は選択の長さがぴったりの場合のみ返す
                if cursor.length == minLength {
                    location = cursor.location
                    getLength = cursor.length
                    fromSelection = true
                    fromMirror = false
                    Log.i("Selection exact desired length: location=\(location) length=\(getLength)")
                    // fall through to get from selection
                } else {
                    Log.i("Selection length doesn't match for requirement: no result")
                    return emptyYomiContext
                }
            } else {
                // min < maxの場合
                // 選択がmin以上max以下の場合のみ選択から返す。それ以外は取得しない(変換しない)
                if cursor.length < minLength {
                    Log.i("Selection length (\(cursor.length)) < minLength (\(minLength)): no result")
                    return emptyYomiContext
                } else if cursor.length > maxLength {
                    Log.i("Selection length (\(cursor.length)) > maxLength (\(maxLength)): no result")
                    return emptyYomiContext
                } else {
                    location = cursor.location
                    getLength = cursor.length
                    fromSelection = true
                    fromMirror = false
                    Log.i("Selection length matches minLength..maxLength: get all of selection")
                    // fall through to get from selection
                }
            }
        } else { // cursor.location != NSNotFound && (cursor.length == 0 || cursor.length == NSNotFound)
            // カーソルは取得できるが選択はない場合
            if cursor.location >= minLength {
                // 最大maxLengthまで取る
                if cursor.location >= maxLength {
                    getLength = maxLength
                } else {
                    getLength = cursor.location
                }
                location = cursor.location - getLength
                fromMirror = false
                fromSelection = false
                Log.i("No selection, enough yomi: location=\(location) length=\(getLength)")
                // fall through to get from selection
            } else {
                // バッファ先頭であり読みがない、または
                // 読みが取れないクライアント(Google Docsなど)
                location = 0
                getLength = 0
                fromMirror = true
                fromSelection = false
                Log.i("No selection, not enough yomi. Using mirror")
                // fall through to get from mirror
            }
        }

        if !fromMirror {
            // クライアントから取得。選択中の場合はrangeが選択範囲となっているはず
            let range = NSRange(location: location, length: getLength)
            Log.i("Trying to get yomi from client: range=\(range)")
            if let text = client.string(from: range, actualRange: &replaceRange) {
                if text.count > 0 {
                    // Google DocsやSlidesはZero-width spaceを1文字返すことがある。その場合はミラーから取る
                    if text != "\u{200b}" {
                        Log.i("Yomi taken from client: text=\(text) at actualRange=\(replaceRange)")
                        return YomiContext(string: text, range: replaceRange, fromSelection: fromSelection, fromMirror: fromMirror)
                    }
                }
            }
            // else fall through
        }
        // ミラーから取得
        fromMirror = true
        if recent.text.count < minLength {
            Log.i("No yomi found from mirror: recent.text.count < minLength")
            return emptyYomiContext
        }
        getLength = if recent.text.count < maxLength { recent.text.count } else { maxLength }
        location = recent.text.count - getLength
        if let text = recent.string(from: NSRange(location: location, length: getLength), actualRange: &replaceRange) {
            if text.count > 0 {
                Log.i("Yomi taken from mirror: text=\(text) at \(replaceRange)")
                return YomiContext(string: text, range: replaceRange, fromSelection: false, fromMirror: fromMirror)
            }
        }
        Log.i("No yomi found from mirror")
        return emptyYomiContext
    }
    // Yomiの後ろ側からlength文字をstringで置きかえる
    func replaceYomi(_ string: String, length: Int, from yomiContext: YomiContext) {
        // yomiContext.range: 読みの位置
        var rr = yomiContext.range
        rr.location += rr.length - length
        rr.length = length
        if yomiContext.fromMirror {
            // Mirrorから読みを取った場合は、BackSpaceを送ってから文字列を送る
            if length < 10 {
                Log.i("Sending \(length) BackSpaces and then \(string)")
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
                // lengthが長すぎるときは単にinsert
                Log.i("★★Can't happen: too long length \(length)")
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            }
            recent.insertText(string, replacementRange: rr)
        } else {
            client.insertText(string, replacementRange: rr)
            recent.replaceLast(length: rr.length, with: string)
        }
    }
}
