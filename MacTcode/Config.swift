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
        // ユーザーのApplication Supportディレクトリを優先して検索
        if let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let macTcodeDir = appSupportDir.appendingPathComponent("MacTcode")
            let configURL = macTcodeDir.appendingPathComponent(file)
            
            if FileManager.default.fileExists(atPath: configURL.path) {
                do {
                    let configContent = try String(contentsOf: configURL, encoding: .utf8)
                    Log.i("Config file \(file) loaded from: \(configURL.path)")
                    return configContent
                } catch {
                    Log.i("Failed to read file \(configURL.path): \(error)")
                }
            }
        }
        
        // バンドルリソースから検索（フォールバック）
        if let configFilePath = Bundle.main.path(forResource: file, ofType: nil) {
            do {
                let configContent = try String(contentsOfFile: configFilePath, encoding: .utf8)
                Log.i("Config file \(file) loaded from bundle: \(configFilePath)")
                return configContent
            } catch {
                Log.i("Failed to read bundle file: \(error)")
            }
        }
        
        Log.i("Config file \(file) not found in any search path")
        return nil
    }
}
