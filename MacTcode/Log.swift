//
//  Log.swift
//  MacTcode
//
//  Created by maeda on 2024/06/09.
//

import Cocoa

class Log {
    static func i(_ message: String) {
#if DEBUG
        NSLog (message)
#endif
    }
}
