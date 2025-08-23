//
//  PostfixBushuAction.swift
//  MacTcode
//
//  Created by maeda on 2024/05/27.
//

import Foundation

class PostfixBushuAction: Action {
    func execute(client: Client, mode: Mode, controller: Controller) -> Command {
        // postfix bushu
        guard let client = client as? ContextClient else {
            Log.i("★★Can't happen: PostfixBushuAction.execute: client is not ContextClient")
            return .processed
        }
        let yomi = client.getYomi(2, 2, yomiCharacters: UserConfigs.shared.bushu.bushuYomiCharacters)
        if yomi.string.count != 2 {
            Log.i("Bushu henkan: no input")
            return .processed
        }
        let chars = yomi.string.map { String($0) }
        let ch1 = chars[0]
        let ch2 = chars[1]
        Log.i("Bushu \(ch1)\(ch2)")

        if let ch = Bushu.i.compose(char1: ch1, char2: ch2) {
            Log.i("Bushu \(ch1)\(ch2) -> \(ch)")
            client.replaceYomi(ch, length: 2, from: yomi)
        } else {
            Log.i("Bushu henkan no candidates for \(ch1)\(ch2)")
        }

        return .processed
    }
}
