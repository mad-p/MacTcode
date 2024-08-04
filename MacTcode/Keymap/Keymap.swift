//
//  Keymap.swift
//  MacTcode
//
//  Created by maeda on 2024/06/01.
//

import Cocoa

let nKeys = 40

/// イベントからコマンドへの対応
class Keymap {
    var name: String
    var map: [InputEvent: Command] = [:]
    init(_ name: String) {
        self.name = name
    }
    init(_ name: String, fromArray chars: [String]) {
        self.name = name
        precondition(chars.count == nKeys, "Keymap \(name) fromChars: must have \(nKeys) characters")
        for i in 0..<nKeys {
            let key = InputEvent(type: .printable, text: Translator.keyToStr(i), event: NSEvent())
            add(key, .text(chars[i]))
        }
    }
    convenience init!(_ name: String, fromChars chars: String) {
        self.init(name, fromArray: chars.map{String($0)})
    }
    init(_ name: String, from2d: String!) {
        self.name = name
        let table = from2d.components(separatedBy: "\n").map { $0.map { String($0) }}
        precondition(table.count == nKeys, "2Dkeymap \(name) from2d: must have \(nKeys) lines")
        // check if we have exactly nKeys in each row
        var ok = true
        for j in 0..<nKeys {
            if table[j].count != nKeys {
                Log.i("2DKeymap \(name) row \(j) must have \(nKeys) chars")
                ok = false
            }
        }
        precondition(ok, "2DKeymap \(name) from2d: had erroneous definition in rows")
        
        // i: first stroke (column in table)
        for i in 0..<nKeys {
            let columnKey = InputEvent(type: .printable, text: Translator.keyToStr(i))
            let columnMap = Keymap("\(name)_column\(i)")
            add(columnKey, .keymap(columnMap))
            // j: second stroke (row in table)
            for j in 0..<nKeys {
                let rowKey = InputEvent(type: .printable, text: Translator.keyToStr(j))
                columnMap.add(rowKey, .text(table[j][i]))
            }
        }
    }
    func lookup(input: InputEvent) -> Command? {
        return map[input]
    }
    func add(_ key: InputEvent, _ entry: Command) {
        if map[key] != nil {
            Log.i("Keymap \(name) replace \(key) to new entry \(String(describing: entry))")
        }
        map[key] = entry
    }
    func replace(input: InputEvent, entry: Command?) {
        if let e = entry {
            add(input, e)
        } else {
            Log.i("Keymap \(name) undefine \(input)")
            map.removeValue(forKey: input)
        }
    }
}
