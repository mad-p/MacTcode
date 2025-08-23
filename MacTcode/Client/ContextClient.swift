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
        let emptyYomiContext = YomiContext(string: "", range: cursor, fromSelection: true, fromMirror: false)
        
        // 選択範囲がある場合
        if let result = tryGetYomiFromSelection(cursor: cursor, minLength: minLength, maxLength: maxLength) {
            return result
        }
        
        // カーソル位置からクライアントの文字列を取得
        if let result = tryGetYomiFromClient(cursor: cursor, minLength: minLength, maxLength: maxLength) {
            return result
        }
        
        // ミラーから取得
        if let result = tryGetYomiFromMirror(minLength: minLength, maxLength: maxLength) {
            return result
        }
        
        Log.i("No yomi found")
        return emptyYomiContext
    }
    
    // 選択範囲から読みを取得
    private func tryGetYomiFromSelection(cursor: NSRange, minLength: Int, maxLength: Int) -> YomiContext? {
        guard cursor.location != NSNotFound && cursor.length != 0 && cursor.length != NSNotFound else {
            return nil
        }
        
        if minLength == maxLength {
            // min = maxの場合は選択の長さがぴったりの場合のみ返す
            if cursor.length == minLength {
                Log.i("Selection exact desired length: location=\(cursor.location) length=\(cursor.length)")
                return tryGetStringFromClient(location: cursor.location, length: cursor.length, fromSelection: true, fromMirror: false)
            } else {
                Log.i("Selection length doesn't match for requirement: no result")
                return YomiContext(string: "", range: cursor, fromSelection: true, fromMirror: false)
            }
        } else {
            // min < maxの場合
            if cursor.length < minLength {
                Log.i("Selection length (\(cursor.length)) < minLength (\(minLength)): no result")
                return YomiContext(string: "", range: cursor, fromSelection: true, fromMirror: false)
            } else if cursor.length > maxLength {
                Log.i("Selection length (\(cursor.length)) > maxLength (\(maxLength)): no result")
                return YomiContext(string: "", range: cursor, fromSelection: true, fromMirror: false)
            } else {
                Log.i("Selection length matches minLength..maxLength: get all of selection")
                return tryGetStringFromClient(location: cursor.location, length: cursor.length, fromSelection: true, fromMirror: false)
            }
        }
    }
    
    // カーソル位置のクライアント文字列から読みを取得
    private func tryGetYomiFromClient(cursor: NSRange, minLength: Int, maxLength: Int) -> YomiContext? {
        guard cursor.location != NSNotFound && (cursor.length == 0 || cursor.length == NSNotFound) else {
            return nil
        }
        
        guard cursor.location >= minLength else {
            Log.i("No selection, not enough yomi. Will try mirror")
            return nil
        }
        
        // 最大maxLengthまで取る
        let getLength = min(cursor.location, maxLength)
        let location = cursor.location - getLength
        Log.i("No selection, trying to get from client: location=\(location) length=\(getLength)")
        
        return tryGetStringFromClient(location: location, length: getLength, fromSelection: false, fromMirror: false)
    }
    
    // クライアントから文字列を取得、yomi文字だけのsuffixを見る
    private func tryGetStringFromClient(location: Int, length: Int, fromSelection: Bool, fromMirror: Bool) -> YomiContext? {
        let range = NSRange(location: location, length: length)
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)
        
        guard let text = client.string(from: range, actualRange: &replaceRange), !text.isEmpty else {
            return nil
        }
        
        // textの最も右側のyomiCharactersの連続した部分文字列を取得
        let yomiText = extractValidYomiSuffix(from: text, minLength: fromSelection ? length : 1)
        if !yomiText.isEmpty {
            // 実際の範囲を調整
            let yomiLength = yomiText.count
            let adjustedRange = NSRange(
                location: replaceRange.location + (replaceRange.length - yomiLength),
                length: yomiLength
            )
            Log.i("Yomi taken from client: text=\(yomiText) at adjustedRange=\(adjustedRange)")
            return YomiContext(string: yomiText, range: adjustedRange, fromSelection: fromSelection, fromMirror: fromMirror)
        }
        
        return nil
    }
    
    // ミラーから読みを取得
    private func tryGetYomiFromMirror(minLength: Int, maxLength: Int) -> YomiContext? {
        guard recent.text.count >= minLength else {
            Log.i("No yomi found from mirror: recent.text.count < minLength")
            return nil
        }
        
        let getLength = min(recent.text.count, maxLength)
        let location = recent.text.count - getLength
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)
        
        guard let text = recent.string(from: NSRange(location: location, length: getLength), actualRange: &replaceRange), !text.isEmpty else {
            return nil
        }
        
        // ミラーからの場合も新しいロジックを適用
        let yomiText = extractValidYomiSuffix(from: text, minLength: minLength)
        if !yomiText.isEmpty {
            // 実際の範囲を調整
            let yomiLength = yomiText.count
            let adjustedRange = NSRange(
                location: replaceRange.location + (replaceRange.length - yomiLength),
                length: yomiLength
            )
            Log.i("Yomi taken from mirror: text=\(yomiText) at adjustedRange=\(adjustedRange)")
            return YomiContext(string: yomiText, range: adjustedRange, fromSelection: false, fromMirror: true)
        }
        
        return nil
    }
    
    // 文字列の最も右側のyomiCharactersの連続した部分文字列を抽出
    private func extractValidYomiSuffix(from text: String, minLength: Int) -> String {
        let yomiCharacters = UserConfigs.shared.ui.yomiCharacters
        
        // 正規表現パターンを構築（グループキャプチャを使用）
        let pattern = "([\(yomiCharacters)]+)$"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            
            if let match = regex.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges > 1 {
                let yomiRange = match.range(at: 1) // グループキャプチャの結果
                if yomiRange.length >= minLength {
                    return nsText.substring(with: yomiRange)
                }
            }
        } catch {
            Log.i("Regex error in extractValidYomiSuffix: \(error)")
        }
        
        return ""
    }
    // Yomiの後ろ側からlength文字をstringで置きかえる
    func replaceYomi(_ string: String, length: Int, from yomiContext: YomiContext) {
        // yomiContext.range: 読みの位置
        var rr = yomiContext.range
        rr.location += rr.length - length
        rr.length = length
        if yomiContext.fromMirror {
            // Mirrorから読みを取った場合は、BackSpaceを送ってから文字列を送る
            let uiConfig = UserConfigs.shared.ui
            if length < uiConfig.backspaceLimit {
                Log.i("Sending \(length) BackSpaces and then \(string)")
                let now = DispatchTime.now()
                for i in 0..<rr.length {
                    DispatchQueue.main.asyncAfter(deadline: now + uiConfig.backspaceDelay * Double(i)) {
                        self.client.sendBackspace()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: now + uiConfig.backspaceDelay * Double(rr.length)) {
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
