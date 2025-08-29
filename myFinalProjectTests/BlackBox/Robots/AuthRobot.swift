//
//  AuthRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//
// test helper for XCUITest that automates common authentication flows.

import XCTest

@MainActor
struct AuthRobot {
    let app: XCUIApplication

    // tiny helper
    @discardableResult
    private func tapButton(_ id: String, timeout: TimeInterval = 6) -> Self {
        let b = app.buttons[id]
        XCTAssertTrue(b.waitForExistence(timeout: timeout), "Button \(id) not found")
        b.tap()
        return self
    }

    // NAV
    @discardableResult func gotoSignUp() -> Self { tapButton("signin.signup") }
    @discardableResult func gotoForgot() -> Self { tapButton("signin.forgot") }

    // SIGN IN
    @discardableResult func enterSignin(email: String, password: String) -> Self {
        let e = app.textFields["signin.email"]
        XCTAssertTrue(e.waitForExistence(timeout: 6), "signin.email not found")
        e.tap(); e.typeText(email)

        let p = app.secureTextFields["signin.password"]
        XCTAssertTrue(p.waitForExistence(timeout: 6), "signin.password not found")
        p.tap(); p.typeText(password)
        return self
    }
    @discardableResult func submitSignin() -> Self { tapButton("signin.continue") }

    // SIGN UP
    @discardableResult func enterSignup(email: String, password: String, confirm: String, agree: Bool = true) -> Self {
        let e = app.textFields["signup.email"]
        XCTAssertTrue(e.waitForExistence(timeout: 6), "signup.email not found")
        e.tap(); e.typeText(email)

        let p = app.secureTextFields["signup.password"]
        XCTAssertTrue(p.waitForExistence(timeout: 6), "signup.password not found")
        p.tap(); p.typeText(password)

        let c = app.secureTextFields["signup.confirm"]
        XCTAssertTrue(c.waitForExistence(timeout: 6), "signup.confirm not found")
        c.tap(); c.typeText(confirm)

        if agree { tapButton("signup.terms") }
        return self
    }
    @discardableResult func submitSignup() -> Self { tapButton("signup.continue") }

    // FORGOT
    @discardableResult func forgotEmail(_ email: String) -> Self {
        let f = app.textFields["forgot.email"]
        XCTAssertTrue(f.waitForExistence(timeout: 6), "forgot.email not found")
        f.tap(); f.typeText(email)
        return self
    }
    @discardableResult func submitForgot() -> Self { tapButton("forgot.submit") }

    // ASSERTIONS
    func assertHome(timeout: TimeInterval = 10) {
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: timeout), "Home not visible")
    }
    func assertProfileSetup(timeout: TimeInterval = 10) {
        XCTAssertTrue(app.otherElements["profilesetup.screen"].waitForExistence(timeout: timeout), "ProfileSetup not visible")
    }
    func assertTextContains(_ id: String, _ expected: String, timeout: TimeInterval = 6) {
        let el = app.staticTexts[id]
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "Expected element id=\(id)")
        XCTAssertTrue(el.label.localizedCaseInsensitiveContains(expected), "Label mismatch: \(el.label)")
    }
    func assertErrorContains(_ fragment: String) {
        let el = app.staticTexts["auth.errorLabel"]
        XCTAssertTrue(el.waitForExistence(timeout: 6), "No error label")
        XCTAssertTrue(el.label.localizedCaseInsensitiveContains(fragment), "Error didn’t contain '\(fragment)' (got: \(el.label))")
    }
}

