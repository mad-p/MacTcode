//
//  MazegakiSelectionMode.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

import Cocoa
import InputMethodKit

class MazegakiSelectionMode: Mode, ModeWithCandidates {
    let map = MazegakiSelectionMap.map
    let mazegaki: Mazegaki
    let hits: [MazegakiHit]
    let controller: Controller
    let candidateWindow: IMKCandidates
    var candidateString: String = ""
    var row: Int
    init(controller: Controller, mazegaki: Mazegaki!, hits: [MazegakiHit]) {
        self.controller = controller
        self.mazegaki = mazegaki
        self.candidateWindow = controller.candidateWindow
        self.hits = hits
        self.row = 0
        Log.i("MazegakiSelectionMode.init")
    }
    func showWindow() {
        candidateWindow.update()
        candidateWindow.show()
    }
    func handle(_ inputEvent: InputEvent, client: ContextClient!, controller: any Controller) -> Bool {
        // キーで選択して確定。右手ホームの4キーの後数字の1～0
        Log.i("MazegakiSelectionMode.handle: event=\(inputEvent) client=\(client!) controller=\(controller)")
        if let selectKeys = candidateWindow.selectionKeys() as? [Int] {
            Log.i("  selectKeys = \(selectKeys)")
            if let keyCode = inputEvent.event?.keyCode {
                Log.i("  keyCode = \(Int(keyCode))")
                if let index = selectKeys.firstIndex(of: Int(keyCode)) {
                    Log.i("  index = \(index)")
                    let candidates = hits[row].candidates()
                    if index < candidates.count {
                        if mazegaki.submit(hit: hits[row], index: index, client: client, controller: controller) {
                            cancel()
                        }
                    }
                    return true
                }
            }
        }
        if let command = map.lookup(input: inputEvent) {
            switch command {
            case .passthrough:
                break
            case .processed:
                break
            case .action(let action):
                Log.i("execute action \(action)")
                _ = action.execute(client: client, mode: self, controller: controller)
                break
            default:
                break
            }
            return true
        }
        switch inputEvent.type {
        case .printable, .enter, .left, .right, .up, .down, .space, .tab:
            if let event = inputEvent.event {
                Log.i("Forward to candidateWindow: \([event])")
                candidateWindow.interpretKeyEvents([event])
            }
            return true
        case .delete, .escape, .control_g:
            cancel()
            return true
        case .control_punct, .unknown:
            return true
        }
    }
    func update() {
        candidateWindow.update()
    }
    func cancel() {
        Log.i("MazegakiSelectionMode.cancel")
        candidateWindow.hide()
        controller.popMode()
    }
    func reset() {
    }

    func candidates(_ sender: Any!) -> [Any]! {
        Log.i("MazegakiSelectionMode.candidates")
        let cands = hits[row].candidates()
        let candsWithKey = cands.enumerated().map { (index, element) in
            let key = UserConfigs.shared.ui.candidateSelectionKeys[index]
            return ("0" <= key && key <= "9") ? "\(key):\(element)" : element
        }
        Log.i("candsWithKey = \(candsWithKey)")
        return candsWithKey
    }

    func candidateSelected(_ candidateString: NSAttributedString!, client: (any Client)!) {
        let cand = candidateString.string
        Log.i("candidateSelected \(cand)")
        let cand2 = cand.replacingOccurrences(
            of: #"^\d:"#,
            with: "",
            options: .regularExpression
        )
        _ = mazegaki.submit(hit: hits[row], string: cand2, client: client, controller: controller)
        cancel()
    }

    func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        self.candidateString = candidateString.string
        Log.i("candidateSelectionChanged \(candidateString.string)")
    }
}
