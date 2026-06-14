//
//  HankanaMode.swift
//  MacTcode
//
//  Created by Kaoru Maeda on 2026/06/14.
//

class HankanaMode: TcodeMode {
    override func filterText(_ text: String) -> String {
        return Hankana().convert(text)
    }
}

