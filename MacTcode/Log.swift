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
        if UserConfigs.i.system.logEnabled {
            Log.i.logger.info("\(message, privacy: .public)")
        }
    }
    static private var i = Log()
    let logger: Logger
    init() {
        logger = Logger(subsystem: "MacTcode", category: "i")
        logger.info("★Logger created")
    }
}
