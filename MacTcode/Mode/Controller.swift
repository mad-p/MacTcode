//
//  Controller.swift
//  MacTcode
//
//  Created by maeda on 2024/08/04.
//

import Foundation
import InputMethodKit

/// モードを持つIMKController
protocol Controller {
    var mode: Mode { get }
    func pushMode(_ mode: Mode)
    func popMode()
    var candidateWindow: IMKCandidates { get }
}
