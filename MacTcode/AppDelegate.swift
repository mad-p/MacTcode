//
//  AppDelegate.swift
//  MacTcode
//
//  Created by maeda on 2024/05/25.
//

import Cocoa
import InputMethodKit

// ---- self-pipe for signal handling ----
var sigpipe: [Int32] = [0, 0]
var gSigpipeW: Int32 = -1

// C呼び出し規約のハンドラ（クロージャ不可）
@_cdecl("sigint_handler")
func sigint_handler(_ signo: Int32, _ info: UnsafeMutablePointer<__siginfo>?, _ uctx: UnsafeMutableRawPointer?) -> Void {
    // async-signal-safe な write() だけを使う
    var one: UInt8 = 1
    // 失敗しても構わない（他にやれることがない）
    _ = withUnsafePointer(to: &one) { ptr in
        ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { p in
            write(gSigpipeW, p, 1)
        }
    }
}

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

        // ---- SIGINT ハンドラの設定 ----
        setupSigintHandler()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.i("★AppDelegate terminating self=\(ObjectIdentifier(self))")
        InputStats.shared.writeStatsToFile()
    }

    private func setupSigintHandler() {
        // self-pipe の作成
        guard pipe(&sigpipe) == 0 else {
            perror("pipe")
            Log.i("★Failed to create signal pipe")
            return
        }
        let sigpipeR = sigpipe[0]
        let sigpipeW = sigpipe[1]
        gSigpipeW = sigpipeW

        Log.i("★Signal pipe created: read=\(sigpipeR), write=\(sigpipeW)")

        // SIGINT を sigaction で捕捉
        var sa = sigaction()
        sigemptyset(&sa.sa_mask)
        sa.sa_flags = SA_SIGINFO
        sa.__sigaction_u.__sa_sigaction = sigint_handler
        guard sigaction(SIGINT, &sa, nil) == 0 else {
            perror("sigaction")
            Log.i("★Failed to setup SIGINT handler")
            return
        }

        Log.i("★SIGINT handler registered")

        // signal watcher スレッド
        Thread.detachNewThread {
            Log.i("★Signal watcher thread started")
            var buf: UInt8 = 0
            while true {
                let n = read(sigpipeR, &buf, 1)
                if n <= 0 {
                    if errno == EINTR {
                        continue
                    } else {
                        break
                    }
                }
                Log.i("★SIGINT received, syncing data...")
                InputStats.shared.writeStatsToFile()
                Log.i("★Data sync completed")
            }
            Log.i("★Signal watcher thread terminated")
        }
    }
}
