//
//  MazegakiDict.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

import Cocoa

final class MazegakiDict {
    static let i = MazegakiDict()

    var dict: [String: String] = [:]
    static let inflectionMark = "—"

    func readDictionary() {
        Log.i("Read mazegaki dictionary...")
        dict = [:]
        let dictionaryFile = UserConfigs.shared.mazegaki.dictionaryFile
        if let mazedic = Config.loadConfig(file: dictionaryFile) {
            for line in mazedic.components(separatedBy: .newlines) {
                let kv = line.components(separatedBy: " ")
                if kv.count == 2 {
                    dict[kv[0]] = kv[1]
                } else {
                    if line.count > 0 {
                        Log.i("Invalid \(dictionaryFile) line: \(line)")
                    }
                }
            }
        }
        Log.i("\(dict.count) mazegaki entries read")
    }

    private init() {
        readDictionary()
    }
}
