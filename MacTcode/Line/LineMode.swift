//
//  LineMode.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2025/11/24.
//

import Cocoa

class LineMode: Mode {
    weak var controller: Controller?
    let map = LineModeMap.map
    let text = RecentTextClient("", 100)
    let recent = RecentTextClient("")
    var line: LineClient?
    init() {
        Log.i("LineMode.init")
    }
    func setController(_ controller: Controller) {
        self.controller = controller
    }
    
    func wrapClient(_ client: ContextClient!) -> ContextClient! {
        line = LineClient(baseClient: client, lineClient: text, recentClient: recent)
        return line
    }
    func handle(_ inputEvent: InputEvent, client: ContextClient!) -> HandleResult {
        Log.i("LineMode.handle \(inputEvent)")
        if let command = map.lookup(input: inputEvent) {
            switch command {
            case .action(let action):
                InputStats.shared.incrementFunctionCount()
                switch action.execute(client: client, mode: self, controller: controller!) {
                case .processed:
                    return .processed
                default:
                    Log.i("★★Can't happen: LineMode action return non-processed?")
                    return .processed
                }
            default:
                Log.i("★★Can't happen: LineMode.handle: unknown command")
                return .forward
            }
        }
        return .forward
    }
    func kakutei() {
        Log.i("LineMode.kakutei")
        line?.sendLine()
        cancel()
    }
    func cancel() {
        Log.i("LineMode.cancel")
        line?.reset()
        controller?.popMode(self)
    }
    func reset() {
        cancel()
    }
}

class ToggleLineModeAction: Action {
    func execute(client: any Client, mode: any Mode, controller: any Controller) -> Command {
        guard let controller = controller as? TcodeInputController else {
            Log.i("★★Can't happen: ActivateLineModeAction: controller is not TcodeInputController")
            return .processed
        }
        // LineMode is a toggle
        if let mode = controller.getActiveMode(of: LineMode.self) {
            // deactivate
            if let mode = mode as? LineMode {
                Log.i("ToggleLineModeAction: kakutei and deactivate")
                mode.kakutei()
                return .processed
            } else {
                Log.i("★★Can't happen. LineMode is not the active mode.")
                return .passthrough
            }
        } else {
            // activate
            Log.i("ToggleLineModeAction: activate")
            let mode = LineMode()
            controller.pushMode(mode)
            // show initial indicator (too adhoc)
            let notFound = NSRange(location: NSNotFound, length: NSNotFound)
            client.setMarkedText("▲", selectionRange: notFound, replacementRange: notFound)
        }
        return .processed
    }
}
