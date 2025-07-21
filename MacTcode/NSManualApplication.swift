//
//  NSManualApplication.swift
//  MacTcode
//
//  Created by maeda on 2024/05/25.
//

import Cocoa

// Copied from https://github.com/ensan-hcl/Typut (MIT License)

/// アプリケーションのエントリポイント
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