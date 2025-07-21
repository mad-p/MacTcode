//
//  Log.swift
//  MacTcode
//
//  Created by maeda on 2024/06/09.
//

import Cocoa

/// ログ出力
class Log {
    static func i(_ message: String) {
        if UserConfigs.shared.system.logEnabled {
            NSLog(message)
        }
    }
}
