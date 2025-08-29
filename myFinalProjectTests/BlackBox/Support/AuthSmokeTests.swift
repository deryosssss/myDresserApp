//
//  AuthSmokeTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//

import XCTest

@MainActor
final class AuthSmokeTests: XCTestCase {
    func test_signInScreen_appears() {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()

        XCTAssertTrue(app.textFields["signin.email"].waitForExistence(timeout: 8), "signin.email not found")
        XCTAssertTrue(app.secureTextFields["signin.password"].waitForExistence(timeout: 2), "signin.password not found")
    }
}
