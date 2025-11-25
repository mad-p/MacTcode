//
//  LineClient.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2025/11/22.
//

import Cocoa

class LineClient: ContextClient {
    let baseClient: Client
    let textClient: RecentTextClient
    init(baseClient: Client, lineClient: RecentTextClient, recentClient: RecentTextClient) {
        self.baseClient = baseClient
        self.textClient = lineClient
        super.init(client: lineClient, recent: recentClient)
    }
    func updateMarkedText() {
        let notFound = NSRange(location: NSNotFound, length: NSNotFound)
        baseClient.setMarkedText("▲" + textClient.text, selectionRange: notFound, replacementRange: notFound)
        Log.i("LineClient: setMarkedText \(textClient.text)")
    }
    func clearMarkedText() {
        let notFound = NSRange(location: NSNotFound, length: NSNotFound)
        baseClient.setMarkedText("", selectionRange: notFound, replacementRange: notFound)
        Log.i("LineClient: clear with setMarkedText")
    }
    func sendLine() {
        Log.i("LineClient: sending line: \(textClient.text)")
        if !textClient.text.isEmpty {
            baseClient.insertText(textClient.text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        reset()
    }
    func reset() {
        textClient.text = ""
        clearMarkedText()
    }
    override func insertText(
        _ string: String,
        replacementRange rr: NSRange
    ) {
        super.insertText(string, replacementRange: rr)
        updateMarkedText()
    }
    override func sendBackspace() {
        textClient.sendBackspace()
        recent.sendBackspace()
        updateMarkedText()
    }
    override func replaceYomi(_ string: String, length: Int, from yomiContext: YomiContext) -> Int {
        if !yomiContext.fromMirror {
            Log.i("LineClient.replaceYomi: from mirror?")
        }

        // yomiContext.range: 読みの位置
        var rr = yomiContext.range
        rr.location += rr.length - length
        rr.length = length
        if rr.location < 0 {
            rr.location = 0
        }
        textClient.insertText(string, replacementRange: rr)
        recent.replaceLast(length: length, with: string)
        updateMarkedText()
        return 0
    }
    override func bundleId() -> String! {
        return Bundle.main.bundleIdentifier
    }
    override func setMarkedText(
        _ string: String,
        selectionRange: NSRange,
        replacementRange: NSRange
    ) {
        // nop
    }
}
