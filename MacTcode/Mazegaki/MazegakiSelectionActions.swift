//
//  MazegakiSelectionActions.swift
//  MacTcode
//
//  Created by maeda on 2024/05/28.
//

import Foundation

class MazegakiAction: Action {
    func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        return .passthrough
    }
    func execute(client: any Client, mode mode1: any Mode, controller: any Controller) -> Command {
        if let mode = mode1 as? MazegakiSelectionMode {
            return action(client: client, mode: mode, controller: controller)
        }
        return .passthrough
    }
}

class MazegakiSelectionCancelAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        Log.i("CancelAction")
        mode.cancel()
        return .processed
    }
}

class MazegakiSelectionKakuteiAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        Log.i("KakuteiAction")
        _ = mode.mazegaki.submit(hit: mode.hits[mode.row], string: mode.candidateString, client: client)
        mode.cancel()
        return .processed
    }
}

/// 次の候補セットに送る(いわゆる再変換)
class MazegakiSelectionNextAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.row < mode.hits.count - 1 {
            mode.row += 1
            mode.update()
        }
        return .processed
    }
}
/// 直前の候補に戻る
class MazegakiSelectionPreviousAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.row > 0 {
            mode.row -= 1
            mode.update()
        }
        return .processed
    }
}
/// 変換を最初からやり直す
class MazegakiSelectionRestartAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        Log.i("RestartAction")
        mode.row = 0
        mode.update()
        return .processed
    }
}
/// 送りがな部分をのばす
class MazegakiSelectionOkuriNobashiAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.mazegaki.inflection {
            let offset = mode.hits[mode.row].offset
            if offset < Mazegaki.maxInflection {
                if let newRow = ((mode.row+1)..<mode.hits.count).first(where: { r in
                    mode.hits[r].offset != offset
                }) {
                    mode.row = newRow
                    mode.update()
                }
            }
        }
        return .processed
    }
}
/// 送りがな部分を縮める
class MazegakiSelectionOkuriChijimeAction: MazegakiAction {
    override func action(client: any Client, mode: MazegakiSelectionMode, controller: any Controller) -> Command {
        if mode.mazegaki.inflection {
            let offset = mode.hits[mode.row].offset
            if offset > 1 {
                if let index = (1...mode.row).first(where: { r in
                    (0..<mode.hits.count).contains(mode.row - r) &&
                    mode.hits[mode.row - r].offset != offset
                }) {
                    mode.row = mode.row - index
                    mode.update()
                } else {
                    mode.row = 0
                    mode.update()
                }
            } else {
                mode.row = 0
                mode.update()
            }
        }
        return .processed
    }
}