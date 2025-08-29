//
//  TestHelpers.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest

extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let start = Date()
        while exists && Date().timeIntervalSince(start) < timeout {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        return !exists
    }
}
