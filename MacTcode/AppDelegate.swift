//
//  AppDelegate.swift
//  MacTcode
//
//  Created by maeda on 2024/05/25.
//

import Cocoa
import InputMethodKit

/// main
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var server = IMKServer()
    var candidatesWindow = IMKCandidates()

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType: kIMKMain)
        Log.i("★AppDelegate launched self=\(ObjectIdentifier(self))")
        
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
        Log.i("★AppDelegate terminated self=\(ObjectIdentifier(self))")
    }
}