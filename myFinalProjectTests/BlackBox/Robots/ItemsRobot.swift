//
//  ItemsRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//

// ItemsRobot.swift (UITests target)
import XCTest

struct ItemsRobot {
    let app: XCUIApplication

    // NAV
    @discardableResult func gotoAddTab() -> Self {
        app.buttons["Add"].firstMatch.tap()
        return self
    }

    // ENTRY
    @discardableResult func addFixtureFromGallery() -> Self {
        let b = app.buttons["items.addFixture"]
        XCTAssertTrue(b.waitForExistence(timeout: 6), "UT fixture button missing")
        b.tap()
        return self
    }

    @discardableResult func addFixtureFromWeb() -> Self {
        let tab = app.otherElements["items.tab"]
        XCTAssertTrue(tab.waitForExistence(timeout: 4))
        app.staticTexts["Web"].tap()
        let b = app.buttons["items.web.fixture"]
        XCTAssertTrue(b.waitForExistence(timeout: 6))
        b.tap()
        return self
    }

    // PREVIEW
    @discardableResult func saveFromPreview() -> Self {
        let save = app.buttons["preview.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 8), "Preview Save not visible")
        save.tap()
        return self
    }

    // ASSERTIONS
    func assertTagVisible(_ text: String, timeout: TimeInterval = 6) {
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
                        .waitForExistence(timeout: timeout), "Missing tag: \(text)")
    }

    func assertSavingBannerGoesAway() {
        let pv = app.otherElements["items.saving"]
        if pv.waitForExistence(timeout: 3) {
            XCTAssertTrue(pv.waitForNonExistence(timeout: 8), "Saving banner stuck")
        }
    }

    func assertError(_ contains: String) {
        let err = app.staticTexts["items.errorLabel"]
        XCTAssertTrue(err.waitForExistence(timeout: 6))
        XCTAssertTrue(err.label.localizedCaseInsensitiveContains(contains),
                      "Unexpected error label: \(err.label)")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let start = Date()
        while exists && Date().timeIntervalSince(start) < timeout {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        return !exists
    }
}
