//
//  Config.swift
//  MacTcode
//
//  Created by maeda on 2024/05/27.
//

import Cocoa

/// 設定ファイル回りの処理
class Config {
    static func loadConfig(file: String) -> String? {
        if let configFilePath = Bundle.main.path(forResource: file, ofType: nil) {
            do {
                let configContent = try String(contentsOfFile: configFilePath, encoding: .utf8)
                return configContent
            } catch {
                Log.i("Failed to read file: \(error)")
                return nil
            }
        } else {
            Log.i("Config file \(file) not found in bundle")
            return nil
        }
    }
}
