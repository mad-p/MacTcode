//
//  AppDelegate.swift
//  MacTcode
//
//  Created by maeda on 2024/05/25.
//

import Cocoa
import InputMethodKit

var termPipe: [Int32] = [-1, -1]

/// main
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var server = IMKServer()
    var candidatesWindow = IMKCandidates()

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType: kIMKMain)
        Log.i("★AppDelegate launched self=\(ObjectIdentifier(self))")

        // 統計情報の初期化
        _ = InputStats.shared
        
        // アクセシビリティ権限の確認
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            Log.i("★アクセシビリティ権限が付与されている")
        } else {
            Log.i("★アクセシビリティ権限がない")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.i("★AppDelegate terminating self=\(ObjectIdentifier(self))")
        InputStats.shared.writeStatsToFile()
        MazegakiDict.i.saveLruData()
        Bushu.i.saveAutoData()
    }
}
