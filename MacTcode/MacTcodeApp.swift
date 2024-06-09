//
//  MacTcodeApp.swift
//  MacTcode
//
//  Created by maeda on 2024/05/25.
//

import Cocoa
import InputMethodKit

// Copied from https://github.com/ensan-hcl/Typut (MIT License)

class NSManualApplication: NSApplication {
    private let appDelegate = AppDelegate()

    override init() {
        super.init()
        self.delegate = appDelegate
    }

    required init?(coder: NSCoder) {
        // No need for implementation
        fatalError("init(coder:) has not been implemented")
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var server = IMKServer()
    var candidatesWindow = IMKCandidates()

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String, bundleIdentifier: Bundle.main.bundleIdentifier)
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(named: "MenuBarIcon")
        statusItem.button?.image = icon
        statusItem.button?.image?.isTemplate = true
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleRowSteppingCandidatePanel, styleType: kIMKMain)
        Log.i("AppDelegate launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.i("AppDelegate terminated")
    }
}
