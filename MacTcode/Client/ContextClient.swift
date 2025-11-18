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
    var client: Client { get { _client } }
    private let _client: Client
    let recent: RecentTextClient
    var lastCursor: NSRange = NSRange(location: NSNotFound, length: NSNotFound)
    init(client: Client, recent: RecentTextClient) {
        self._client = client
        self.recent = recent
    }
    func bundleId() -> String! {
        return client.bundleId()
    }
    func selectedRange() -> NSRange {
        return client.selectedRange()
    }
    func string(
        from range: NSRange,
        actualRange: NSRangePointer
    ) -> String! {
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
            recent.replaceLast(length: rr.length, with: string)
        }
    }
    func sendBackspace() {
        Log.i("ContextClient.sendBackspace")
        client.sendBackspace()
    }
    // カーソル直前にある読みを取得する
    // クライアントが対応していなければrecentから取る
    func getYomi(_ minLength: Int, _ maxLength: Int, yomiCharacters: String) -> YomiContext {
        let cursor = client.selectedRange()
        lastCursor = cursor
        Log.i("getYomi: cursor=\(cursor) minLength=\(minLength) maxLength=\(maxLength)")
        let emptyYomiContext = YomiContext(string: "", range: cursor, fromSelection: true, fromMirror: false)
        
        // 選択範囲がある場合
        if let result = tryGetYomiFromSelection(cursor: cursor, minLength: minLength, maxLength: maxLength, yomiCharacters: yomiCharacters) {
            return result
        }
        
        // カーソル位置からクライアントの文字列を取得
        if let result = tryGetYomiFromClient(cursor: cursor, minLength: minLength, maxLength: maxLength, yomiCharacters: yomiCharacters) {
            return result
        }
        
        // ミラーから取得
        if let result = tryGetYomiFromMirror(minLength: minLength, maxLength: maxLength, yomiCharacters: yomiCharacters) {
            return result
        }
        
        Log.i("No yomi found")
        return emptyYomiContext
    }
    
    // 選択範囲から読みを取得
    private func tryGetYomiFromSelection(cursor: NSRange, minLength: Int, maxLength: Int, yomiCharacters: String) -> YomiContext? {
        guard cursor.location != NSNotFound && cursor.length != 0 && cursor.length != NSNotFound else {
            return nil
        }
        
        if minLength == maxLength {
            // min = maxの場合は選択の長さがぴったりの場合のみ返す
            if cursor.length == minLength {
                Log.i("Selection exact desired length: location=\(cursor.location) length=\(cursor.length)")
                return tryGetStringFromClient(location: cursor.location, length: cursor.length, fromSelection: true, fromMirror: false, yomiCharacters: yomiCharacters)
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
                return tryGetStringFromClient(location: cursor.location, length: cursor.length, fromSelection: true, fromMirror: false, yomiCharacters: yomiCharacters)
            }
        }
    }
    
    // カーソル位置のクライアント文字列から読みを取得
    private func tryGetYomiFromClient(cursor: NSRange, minLength _minLength: Int, maxLength: Int, yomiCharacters: String) -> YomiContext? {
        var minLength = _minLength
        guard cursor.location != NSNotFound && (cursor.length == 0 || cursor.length == NSNotFound) else {
            return nil
        }
        
        guard cursor.location >= minLength else {
            Log.i("No selection, not enough yomi. Will try mirror")
            return nil
        }
        
        let systemConfig = UserConfigs.shared.system
        if systemConfig.disableOneYomiApplications.contains(client.bundleId()) {
            if minLength < 2 {
                minLength = 2
            }
        }
        
        // 最大maxLengthまで取る
        let getLength = min(cursor.location, maxLength)
        let location = cursor.location - getLength
        Log.i("No selection, trying to get from client: location=\(location) length=\(getLength)")
        
        let result = tryGetStringFromClient(location: location, length: getLength, fromSelection: false, fromMirror: false, yomiCharacters: yomiCharacters)

        guard let result = result else {
            return nil
        }
        // Google Docs/Slidesで読みが取れない場合に対応
        if (result.string.count < minLength) {
            if recent.text.count >= minLength {
                Log.i("Not enough yomi from client, but recent has enough")
                return nil
            }
        }
        
        // recentを見る限りもっと取れそうなのに少ししか取れなかった場合は怪しい
        if (result.string.count < getLength) {
            if recent.text.count > result.string.count {
                Log.i("Tried to get \(getLength), but got only \(result.string.count)")
                return nil
            }
        }
        return result
    }
    
    // クライアントから文字列を取得、yomi文字だけのsuffixを見る
    private func tryGetStringFromClient(location: Int, length: Int, fromSelection: Bool, fromMirror: Bool, yomiCharacters: String) -> YomiContext? {
        let range = NSRange(location: location, length: length)
        var replaceRange = NSRange(location: NSNotFound, length: NSNotFound)
        
        guard let text = client.string(from: range, actualRange: &replaceRange), !text.isEmpty else {
            return nil
        }
        
        // textの最も右側のyomiCharactersの連続した部分文字列を取得
        let yomiText = extractValidYomiSuffix(from: text, minLength: fromSelection ? length : 1, yomiCharacters: yomiCharacters)
        if !yomiText.isEmpty {
            let actualRange = findActualRangeForYomiText(yomiText, in: replaceRange, using: client)
            Log.i("Yomi taken from client: text=\(yomiText) at actualRange=\(actualRange)")
            return YomiContext(string: yomiText, range: actualRange, fromSelection: fromSelection, fromMirror: fromMirror)
        }
        
        return nil
    }
    
    // ミラーから読みを取得
    private func tryGetYomiFromMirror(minLength: Int, maxLength: Int, yomiCharacters: String) -> YomiContext? {
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
        let yomiText = extractValidYomiSuffix(from: text, minLength: minLength, yomiCharacters: yomiCharacters)
        if !yomiText.isEmpty {
            // 2分法でyomiTextと一致するactualRangeを取得（recentクライアントを使用）
            let actualRange = findActualRangeForYomiText(yomiText, in: replaceRange, using: recent)
            Log.i("Yomi taken from mirror: text=\(yomiText) at actualRange=\(actualRange)")
            return YomiContext(string: yomiText, range: actualRange, fromSelection: false, fromMirror: true)
        }
        
        return nil
    }
    
    // 文字列の最も右側のyomiCharactersの連続した部分文字列を抽出
    internal func extractValidYomiSuffix(from text: String, minLength: Int, yomiCharacters: String) -> String {
        
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
    
    // yomiTextと一致する部分のactualRangeを取得
    private func findActualRangeForYomiText(_ yomiText: String, in originalRange: NSRange, using client: Client) -> NSRange {
        guard !yomiText.isEmpty else { return originalRange }
        
        let yomiLength = yomiText.count
        let originalLength = originalRange.length
        
        // yomiTextの長さが元の範囲より大きい場合はoriginalRangeを返す
        guard yomiLength <= originalLength else { return originalRange }
        // Log.i("ContextClient.findActualRangeForYomiText start using \(type(of:client)): yomi=\(yomiText), originalRange=\(originalRange), yomiLength=\(yomiLength), originalLength=\(originalLength)")
        
        if let result = findActualRangeLinear(yomiText, in: originalRange, using: client) {
            // Log.i("ContextClient.findActualRangeForYomiText: return linear search result: \(result)")
            return result
        }
        
        // 線形検索でも見つからない場合はoriginalRangeをフォールバックとして返す
        // Log.i("ActualRange not found for yomiText: \(yomiText), using originalRange as fallback")
        return originalRange
    }
    
    // 線形検索でyomiTextと一致する部分のactualRangeを取得（フォールバック用）
    private func findActualRangeLinear(_ yomiText: String, in originalRange: NSRange, using client: Client) -> NSRange? {
        guard !yomiText.isEmpty else { return nil }
        
        let yomiLength = yomiText.count
        let originalLength = originalRange.length
        
        guard yomiLength <= originalLength else { return nil }
        
        // 右端から左に向かって検索（suffix検索のため）
        for offset in 0...(originalLength - yomiLength) {
            let testRange = NSRange(location: originalRange.location + originalLength - yomiLength - offset, length: yomiLength)
            var actualRange = NSRange(location: NSNotFound, length: NSNotFound)
            
            if let testString = client.string(from: testRange, actualRange: &actualRange),
               testString == yomiText {
                return actualRange
            }
        }
        
        return nil
    }
    
    // Yomiの後ろ側からlength文字をstringで置きかえる。送ったBackspaceの数を返す
    func replaceYomi(_ string: String, length: Int, from yomiContext: YomiContext) -> Int {
        // Log.i("ContextClient.replaceYomi: string=\(string), length=\(length)")
        // Log.i("   yomiContext=\(yomiContext)")

        // yomiContext.range: 読みの位置
        var rr = yomiContext.range
        rr.location += rr.length - length
        rr.length = length
        if rr.location < 0 {
            rr.location = 0
        }
        if yomiContext.fromMirror {
            // Mirrorから読みを取った場合は、BackSpaceを送ってから文字列を送る
            let uiConfig = UserConfigs.shared.ui
            if length < uiConfig.backspaceLimit {
                Log.i("Sending \(length) BackSpaces and then \(string)")
                let now = DispatchTime.now()
                for i in 0..<length {
                    DispatchQueue.main.asyncAfter(deadline: now + uiConfig.backspaceDelay * Double(i)) {
                        self.client.sendBackspace()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: now + uiConfig.backspaceDelay * Double(length)) {
                    self.client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                }
                // Log.i("ContextClient.replaceYomi: calling recent.insertText \(string), \(rr)")
                recent.insertText(string, replacementRange: rr)
                return length
            } else {
                // lengthが長すぎるときは単にinsert
                Log.i("★★Can't happen: too long length \(length)")
                client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                recent.insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
                return 0
            }
        } else {
            client.insertText(string, replacementRange: rr)
            recent.replaceLast(length: length, with: string)
            return 0
        }
    }
}
