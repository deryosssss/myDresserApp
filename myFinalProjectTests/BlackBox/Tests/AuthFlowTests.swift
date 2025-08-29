//
//  AuthFlowTests.swift
//  myFinalProjectUITests
//
//  Created by Derya Baglan on 24/08/2025.
//
// UI test suite for the app’s authentication flows using the Firebase Auth emulator. It covers:
// Sign-up: happy path, duplicate email, weak password, invalid email, mismatched password, and terms not accepted.
// Email verification: handling valid links (success) and noting emulator skips for expired/reuse.
// Login: success, wrong password, non-existent account, and deleted account (placeholder).
// Password recovery: starting reset (generic confirmation), unregistered email handling, and completing a reset with a new strong password (old password rejected).
// Account deletion: confirming and cancelling delete flows.
// It uses AuthRobot for cleaner UI steps, Fixtures for test credentials, and FirebaseEmulator to simulate backend behavior.

import XCTest

@MainActor
final class AuthFlowTests: XCTestCase {
    var app: XCUIApplication!
    let emu = FirebaseEmulator()
    let fx = Fixtures.self

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1", "--signout=1"]
        app.launch()
    }

    // BB-AUTH-FR1-01 — Register new account (happy path)
    func test_BB_AUTH_FR1_01_register_new_account_happy() async throws {
        let email = fx.uniq("ava")
        AuthRobot(app: app)
            .gotoSignUp()
            .enterSignup(email: email, password: fx.strong, confirm: fx.strong)
            .submitSignup()

        // App shows verification screen; mark verified in emulator then confirm in UI.
        let link = try await emu.sendVerify(email: email)
        try await emu.consumeVerifyLink(link)
        app.buttons["verify.confirmed"].tap()

        AuthRobot(app: app).assertProfileSetup()
    }

    // BB-AUTH-FR1-02 — Reject duplicate email
    func test_BB_AUTH_FR1_02_reject_duplicate_email() async throws {
        let email = fx.uniq("dup")
        try await emu.createUser(email: email, password: fx.strong)

        AuthRobot(app: app)
            .gotoSignUp()
            .enterSignup(email: email, password: fx.strong, confirm: fx.strong)
            .submitSignup()

        AuthRobot(app: app).assertErrorContains("in use")
    }

    // BB-AUTH-FR1-03 — Reject weak password
    func test_BB_AUTH_FR1_03_reject_weak_password() {
        AuthRobot(app: app)
            .gotoSignUp()
            .enterSignup(email: fx.uniq("weak"), password: fx.weak, confirm: fx.weak)
            .submitSignup()
        AuthRobot(app: app).assertErrorContains("Password")
    }

    // BB-AUTH-FR1-04 — Invalid email
    func test_BB_AUTH_FR1_04_reject_invalid_email_format() {
        AuthRobot(app: app)
            .gotoSignUp()
            .enterSignup(email: "ava@@example", password: fx.strong, confirm: fx.strong)
            .submitSignup()
        AuthRobot(app: app).assertErrorContains("valid email")
    }

    // BB-AUTH-FR1-05 — Password mismatch
    func test_BB_AUTH_FR1_05_password_mismatch() {
        AuthRobot(app: app)
            .gotoSignUp()
            .enterSignup(email: fx.uniq("mismatch"), password: fx.strong, confirm: fx.strong + "!")
            .submitSignup()
        AuthRobot(app: app).assertErrorContains("match")
    }

    // BB-AUTH-FR1-06 — Terms not accepted
    func test_BB_AUTH_FR1_06_terms_not_accepted_blocked() {
        let email = fx.uniq("terms")
        app.buttons["signin.signup"].tap()
        app.textFields["signup.email"].tap(); app.textFields["signup.email"].typeText(email)
        app.secureTextFields["signup.password"].tap(); app.secureTextFields["signup.password"].typeText(fx.strong)
        app.secureTextFields["signup.confirm"].tap(); app.secureTextFields["signup.confirm"].typeText(fx.strong)
        app.buttons["signup.continue"].tap()
        AuthRobot(app: app).assertErrorContains("agree")
    }

    // BB-AUTH-FR1-07 — Email verification link (valid) → next login succeeds
    func test_BB_AUTH_FR1_07_email_verification_valid_link_login_succeeds() async throws {
        let email = fx.uniq("verify")
        try await emu.createUser(email: email, password: fx.strong)
        let link = try await emu.sendVerify(email: email)
        try await emu.consumeVerifyLink(link)

        AuthRobot(app: app)
            .enterSignin(email: email, password: fx.strong)
            .submitSignin()
            .assertHome()
    }

    // BB-AUTH-FR1-08 — Expired link (emulator doesn’t expire)
    func test_BB_AUTH_FR1_08_email_verification_expired_link() throws {
        throw XCTSkip("Auth emulator doesn't produce expired links.")
    }

    // BB-AUTH-FR1-09 — Link reuse (emulator is idempotent; skip)
    func test_BB_AUTH_FR1_09_email_verification_reuse() throws {
        throw XCTSkip("Auth emulator accepts reuse; assert in end-to-end web tests instead.")
    }

    // BB-AUTH-FR2-01 — Login success
    func test_BB_AUTH_FR2_01_login_success() async throws {
        let email = fx.uniq("login")
        try await emu.createUser(email: email, password: fx.strong)
        AuthRobot(app: app)
            .enterSignin(email: email, password: fx.strong)
            .submitSignin()
            .assertHome()
    }

    // BB-AUTH-FR2-02 — Wrong password → generic error
    func test_BB_AUTH_FR2_02_wrong_password_generic_error() async throws {
        let email = fx.uniq("wrong")
        try await emu.createUser(email: email, password: fx.strong)
        AuthRobot(app: app)
            .enterSignin(email: email, password: "WrongPass123!")
            .submitSignin()
        AuthRobot(app: app).assertErrorContains("Incorrect email or password")
    }

    // BB-AUTH-FR2-03 — Non-existent account → same generic error
    func test_BB_AUTH_FR2_03_nonexistent_account_generic_error() {
        AuthRobot(app: app)
            .enterSignin(email: "nobody@example.com", password: "Whatever123!")
            .submitSignin()
        AuthRobot(app: app).assertErrorContains("Incorrect email or password")
    }

    // BB-AUTH-FR2-04 — Deleted account cannot login (enable after wiring full deletion path)
    func test_BB_AUTH_FR2_04_deleted_account_cannot_login() throws {
        throw XCTSkip("Cover after wiring a deterministic delete path reachable in tests.")
    }

    // BB-AUTH-FR3-01 — Start password recovery → generic confirmation
    func test_BB_AUTH_FR3_01_start_password_recovery_generic_message() async throws {
        let email = fx.uniq("recover")
        try await emu.createUser(email: email, password: fx.strong)
        AuthRobot(app: app).gotoForgot().forgotEmail(email).submitForgot()
        AuthRobot(app: app).assertTextContains("forgot.confirmation", "reset link has been sent")
    }

    // BB-AUTH-FR3-02 — Recovery unregistered email → same generic response
    func test_BB_AUTH_FR3_02_recovery_unregistered_same_response() {
        AuthRobot(app: app).gotoForgot().forgotEmail("ghost@example.com").submitForgot()
        AuthRobot(app: app).assertTextContains("forgot.confirmation", "reset link has been sent")
    }

    // BB-AUTH-FR3-03 — Reset with strong password → login with new works, old fails
    func test_BB_AUTH_FR3_03_reset_with_strong_password_old_rejected() async throws {
        let email = fx.uniq("resetStrong")
        try await emu.createUser(email: email, password: fx.strong)
        let link = try await emu.sendReset(email: email)
        try await emu.resetPassword(using: link, to: Fixtures.strongNew)

        AuthRobot(app: app)
            .enterSignin(email: email, password: Fixtures.strongNew)
            .submitSignin()
            .assertHome()

        app.terminate(); app.launch()

        AuthRobot(app: app)
            .enterSignin(email: email, password: Fixtures.strong)
            .submitSignin()
        AuthRobot(app: app).assertErrorContains("Incorrect")
    }

    // BB-AUTH-FR3-04/05/06 — Hosted reset flows (skip; covered by web E2E)
    func test_BB_AUTH_FR3_04_reset_with_weak_password_blocked() throws { throw XCTSkip("Hosted by Firebase; cover in web E2E.") }
    func test_BB_AUTH_FR3_05_reset_token_reuse_second_invalid() throws { throw XCTSkip("Depends on in-app handling of reused token.") }
    func test_BB_AUTH_FR3_06_multiple_requests_only_newest_works() throws { throw XCTSkip("Depends on in-app reset screen.") }

    // BB-AUTH-FR5-* — Delete account UI flows (IDs already added)
    func test_BB_AUTH_FR5_01_delete_account_confirmed_shows_deleted_and_logs_out() throws {
        app.buttons["settings.confirmDelete"].tap()
        // Add assertion once your post-deletion screen exposes an ID (e.g., "signinup.screen")
    }
    func test_BB_AUTH_FR5_02_delete_account_cancel_sends_home() {
        app.buttons["settings.cancelDelete"].tap()
        AuthRobot(app: app).assertHome()
    }
}
