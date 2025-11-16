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
    var mruDict: [String: String] = [:]  // MRU学習データ
    var toSyncMruDict = false
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

        // MRU学習データを読み込む
        if UserConfigs.shared.mazegaki.mruEnabled {
            loadMruData()
        }
    }

    /// MRU学習データを読み込む
    func loadMruData() {
        Log.i("Load mazegaki MRU data...")
        mruDict = [:]
        let mruFile = UserConfigs.shared.mazegaki.mruFile
        if let mruData = UserConfigs.shared.loadConfig(file: mruFile) {
            for line in mruData.components(separatedBy: .newlines) {
                let kv = line.components(separatedBy: " ")
                if kv.count == 2 {
                    mruDict[kv[0]] = kv[1]
                } else {
                    if line.count > 0 {
                        Log.i("Invalid \(mruFile) line: \(line)")
                    }
                }
            }
        }
        Log.i("\(mruDict.count) mazegaki MRU entries loaded")
        toSyncMruDict = false
    }

    /// MRU学習データを保存する
    func saveMruData() {
        guard UserConfigs.shared.mazegaki.mruEnabled else {
            return
        }
        guard toSyncMruDict else {
            Log.i("Mazegaki.mruDict is clean. No need to save.")
            return
        }
        

        Log.i("Save mazegaki MRU data...")
        let mruFile = UserConfigs.shared.mazegaki.mruFile
        var lines: [String] = []
        for (key, value) in mruDict.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key) \(value)")
        }
        let content = lines.joined(separator: "\n")

        do {
            let url = UserConfigs.shared.configFileURL(mruFile)
            try content.write(to: url, atomically: true, encoding: .utf8)
            Log.i("Mazegaki MRU data saved: \(mruDict.count) entries to \(url.path)")
            toSyncMruDict = false
        } catch {
            Log.i("Failed to save mazegaki MRU data: \(error)")
        }
    }

    /// 選択された候補を先頭に移動する
    /// - Parameters:
    ///   - key: 辞書のキー
    ///   - selectedCandidate: 選択された候補（活用なし）
    func updateMruEntry(key: String, selectedCandidate: String) {
        guard UserConfigs.shared.mazegaki.mruEnabled else {
            return
        }

        // 現在の候補リストを取得（MRU優先）
        guard let entry = mruDict[key] ?? dict[key] else {
            Log.i("updateMruEntry: key '\(key)' not found in dict")
            return
        }

        var candidates = entry.components(separatedBy: "/").filter({ $0 != "" })
        if (candidates.count == 1) {
            // 候補がひとつしかなければ何もする必要がない
            return
        }

        // selectedCandidateを先頭に移動
        if let index = candidates.firstIndex(of: selectedCandidate) {
            if index > 0 {
                candidates.remove(at: index)
                candidates.insert(selectedCandidate, at: 0)

                // mruDictを更新
                mruDict[key] = "/" + candidates.joined(separator: "/") + "/"
                Log.i("updateMruEntry: '\(key)' updated, '\(selectedCandidate)' moved to front")
                toSyncMruDict = true
            } else {
                Log.i("updateMruEntry: '\(selectedCandidate)' already at front")
            }
        } else {
            Log.i("updateMruEntry: '\(selectedCandidate)' not found in candidates")
        }
    }

    private init() {
        readDictionary()
    }
}
