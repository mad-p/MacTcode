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
    var lruDict: [String: String] = [:]  // LRU学習データ
    static let inflectionMark = "—"

    func readDictionary() {
        Log.i("Read mazegaki dictionary...")
        dict = [:]
        let dictionaryFile = UserConfigs.shared.mazegaki.dictionaryFile
        if let mazedic = UserConfigs.shared.loadConfig(file: dictionaryFile) {
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

        // LRU学習データを読み込む
        if UserConfigs.shared.mazegaki.lruEnabled {
            loadLruData()
        }
    }

    /// LRU学習データを読み込む
    func loadLruData() {
        Log.i("Load mazegaki LRU data...")
        lruDict = [:]
        let lruFile = UserConfigs.shared.mazegaki.lruFile
        if let lruData = UserConfigs.shared.loadConfig(file: lruFile) {
            for line in lruData.components(separatedBy: .newlines) {
                let kv = line.components(separatedBy: " ")
                if kv.count == 2 {
                    lruDict[kv[0]] = kv[1]
                } else {
                    if line.count > 0 {
                        Log.i("Invalid \(lruFile) line: \(line)")
                    }
                }
            }
        }
        Log.i("\(lruDict.count) mazegaki LRU entries loaded")
    }

    /// LRU学習データを保存する
    func saveLruData() {
        guard UserConfigs.shared.mazegaki.lruEnabled else {
            return
        }

        Log.i("Save mazegaki LRU data...")
        let lruFile = UserConfigs.shared.mazegaki.lruFile
        var lines: [String] = []
        for (key, value) in lruDict.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key) /\(value)/")
        }
        let content = lines.joined(separator: "\n")

        do {
            let url = UserConfigs.shared.configFileURL(lruFile)
            try content.write(to: url, atomically: true, encoding: .utf8)
            Log.i("Mazegaki LRU data saved: \(lruDict.count) entries to \(url.path)")
        } catch {
            Log.i("Failed to save mazegaki LRU data: \(error)")
        }
    }

    /// 選択された候補を先頭に移動する
    /// - Parameters:
    ///   - key: 辞書のキー
    ///   - selectedCandidate: 選択された候補（活用なし）
    func updateLruEntry(key: String, selectedCandidate: String) {
        guard UserConfigs.shared.mazegaki.lruEnabled else {
            return
        }

        // 現在の候補リストを取得（LRU優先）
        guard let entry = lruDict[key] ?? dict[key] else {
            Log.i("updateLruEntry: key '\(key)' not found in dict")
            return
        }

        var candidates = entry.components(separatedBy: "/").filter({ $0 != "" })
        if (candidates.count == 1) {
            return
        }

        // selectedCandidateを先頭に移動
        if let index = candidates.firstIndex(of: selectedCandidate) {
            if index > 0 {
                candidates.remove(at: index)
                candidates.insert(selectedCandidate, at: 0)

                // lruDictを更新
                lruDict[key] = "/" + candidates.joined(separator: "/") + "/"
                Log.i("updateLruEntry: '\(key)' updated, '\(selectedCandidate)' moved to front")
            } else {
                Log.i("updateLruEntry: '\(selectedCandidate)' already at front")
            }
        } else {
            Log.i("updateLruEntry: '\(selectedCandidate)' not found in candidates")
        }
    }

    private init() {
        readDictionary()
    }
}
