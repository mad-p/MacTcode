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
        
        // シグナルハンドラの設定
        AppDelegate.setupSignalHandlers()

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
    }
    
    /// シグナルハンドラを設定
    static func setupSignalHandlers() {
        // パイプ（[読端, 書端]）
        guard pipe(&termPipe) == 0 else { fatalError("pipe failed") }
        
        NSLog("★Setting up signal handlers...")
        
        // C呼出規約、キャプチャなし
        let sigtermHandler: @convention(c) (Int32) -> Void = { _ in
            var one: UInt8 = 1
            // write は async-signal-safe
            _ = withUnsafePointer(to: &one) {
                $0.withMemoryRebound(to: UInt8.self, capacity: 1) {
                    write(termPipe[1], $0, 1)
                }
            }
        }
        
        // シグナル登録
        signal(SIGINT, sigtermHandler)
        signal(SIGTERM, sigtermHandler)
        
        // SIGINT用のDispatchSourceを作成
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSource.setEventHandler {
            NSLog("★Received SIGINT, writing statistics...")
            InputStats.shared.writeStatsToFile()
            MazegakiDict.i.saveLruData()
            exit(0)
        }
        sigintSource.resume()

        // SIGTERM用のDispatchSourceを作成
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigtermSource.setEventHandler {
            Log.i("★Received SIGTERM, writing statistics...")
            InputStats.shared.writeStatsToFile()
            MazegakiDict.i.saveLruData()
            exit(0)
        }
        sigtermSource.resume()
    }
}
