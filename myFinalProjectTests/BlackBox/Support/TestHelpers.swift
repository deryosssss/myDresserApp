//
//  TestHelpers.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest
// It repeatedly checks until the element disappears (or times out), which is useful in UI tests to confirm that temporary banners, spinners, or dialogs have been dismissed. 
extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let start = Date()
        while exists && Date().timeIntervalSince(start) < timeout {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        return !exists
    }
}
