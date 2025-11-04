//
//  Log.swift
//  MacTcode
//
//  Created by maeda on 2024/06/09.
//

import Cocoa
import os

/// ログ出力
class Log {
    static func i(_ message: String) {
        if UserConfigs.shared.system.logEnabled {
            Log.shared.logger.info("\(message, privacy: .public)")
        }
    }
    static private var shared = Log()
    let logger: Logger
    init() {
        logger = Logger(subsystem: "MacTcode", category: "i")
        logger.info("★Logger created")
    }
}
