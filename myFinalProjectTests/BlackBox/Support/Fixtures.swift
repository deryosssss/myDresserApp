//
//  Fixtures.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//

import Foundation

enum Fixtures {
    static func uniq(_ prefix: String) -> String {
        "\(prefix)+\(Int(Date().timeIntervalSince1970))@example.com"
    }
    static let strong = "ABCD1234"
    static let strongNew = "ABCDE12345"
    static let weak = "12345"
}
