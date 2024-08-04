//
//  MirroringClient.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Cocoa

/// 部首変換、交ぜ書き変換への入力を取得するためのClient
/// クライアントのカーソル周辺の文字列、もし得られなければRecentTextClientから取るClient
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
