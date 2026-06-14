//
//  HankanaMode.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2026/06/14.
//

import Cocoa

class HankanaMode: Mode {
    weak var controller: Controller?
    func setController(_ controller: Controller) {
        self.controller = controller
    }
    func wrapClient(_ client: ContextClient!) -> ContextClient! {
        return HankanaContextClient(client: client, recent: client.recent)
    }
    func reset() {
        controller?.popMode(self)
        controller?.setInputMode(.tcode)
    }
    func handle(_ inputEvent: InputEvent, client: ContextClient!) -> HandleResult {
        Log.i("HankanaMode.handle \(inputEvent)")
        switch inputEvent.type {
        case .escape, .enter:
            reset()
            return .processed
        default:
            return .forward
        }
    }
}
        
class HankanaContextClient: ContextClient {
    override func insertText(_ string: String, replacementRange rr: NSRange) {
        let hankana = Hankana().convert(string)
        super.insertText(hankana, replacementRange: rr)
    }
}
