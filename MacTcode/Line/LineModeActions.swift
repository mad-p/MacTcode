//
//  LineModeActions.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2025/11/24.
//

import Foundation

/// LineModeで使うActionのベースクラス
class LineModeAction: Action {
    func action(client: LineClient, mode: LineMode, controller: any Controller) -> Command {
        return .passthrough
    }
    func execute(client: any Client, mode mode1: any Mode, controller: any Controller) -> Command {
        if let lineClient = client as? LineClient,
           let lineMode = mode1 as? LineMode {
            return action(client: lineClient, mode: lineMode, controller: controller)
        } else {
            return .passthrough
        }
    }
}

class LineModeKakuteiAction: LineModeAction {
    override func action(client: LineClient, mode: LineMode, controller: any Controller) -> Command {
        Log.i("LineModeKakuteiAction")
        mode.kakutei()
        return .processed
    }
}

class LineModeCancelAction: LineModeAction {
    override func action(client: LineClient, mode: LineMode, controller: any Controller) -> Command {
        Log.i("LineModeCancelAction")
        mode.cancel()
        return .processed
    }
}

class LineModeBackspaceAction: LineModeAction {
    override func action(client: LineClient, mode: LineMode, controller: any Controller) -> Command {
        Log.i("LineModeBackspaceAction")
        client.sendBackspace()
        return .processed
    }
}
