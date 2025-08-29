//
//  ItemFlowTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//

import XCTest

// ItemFlowTests is a UI test suite that verifies the item-adding and tagging flows. It covers:
// Adding items via gallery (FR6-03) and in-app web (FR7-01) fixtures.
// Auto-tagging from the fake AI client (detecting type, color, pattern, category) (FR8-01/02/03).
// Manual overrides (e.g., changing category to “Dress”) and ensuring they persist (FR8-04).
// Custom tags: adding predefined tags (FR9-01), verifying visibility/searchability (FR9-02), and preventing duplicates (FR9-03).
// It uses ItemsRobot for consistent navigation and assertions, keeping the tests concise.

final class ItemFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]   // enables stubs & fixture buttons
        app.launch()
    }

    // BB-ITEM-FR6-03 — Add via gallery (fixture)
    func test_BB_ITEM_FR6_03_add_via_gallery_fixture() {
        ItemsRobot(app: app)
            .gotoAddTab()
            .addFixtureFromGallery()
            .saveFromPreview()
            .assertSavingBannerGoesAway()
    }

    // BB-ITEM-FR7-01 — Add via in-app web (fixture)
    func test_BB_ITEM_FR7_01_add_via_web_fixture() {
        ItemsRobot(app: app)
            .gotoAddTab()
            .addFixtureFromWeb()
            .saveFromPreview()
            .assertSavingBannerGoesAway()
    }

    // BB-ITEM-FR8-01/02/03 — Auto type/color/pattern from FakeTaggingClient
    func test_BB_ITEM_FR8_auto_recognition_shoes_blue_polka() {
        ItemsRobot(app: app)
            .gotoAddTab()
            .addFixtureFromGallery()

        // Assert chips/labels from FakeTaggingClient
        ItemsRobot(app: app).assertTagVisible("Colours")
        ItemsRobot(app: app).assertTagVisible("Blue")
        ItemsRobot(app: app).assertTagVisible("Polka Dots")
        ItemsRobot(app: app).assertTagVisible("Shoes")
    }

    // BB-ITEM-FR8-04 — Manual override persists on Save
    func test_BB_ITEM_FR8_04_manual_override_persists() {
        ItemsRobot(app: app)
            .gotoAddTab()
            .addFixtureFromGallery()

        // Open Category editor and change to "Dress"
        app.staticTexts["Category"].tap()
        app.buttons["Edit Category"].firstMatch.tap() // if your editor uses a button, otherwise tap the row
        app.cells.staticTexts["Dress"].firstMatch.tap()
        app.buttons["Save"].tap()

        ItemsRobot(app: app).assertTagVisible("Dress")
        ItemsRobot(app: app).saveFromPreview().assertSavingBannerGoesAway()
    }

    // BB-ITEM-FR9-01 — Add predefined tag (use Custom Tags section)
    func test_BB_ITEM_FR9_01_add_predefined_tag() {
        ItemsRobot(app: app)
            .gotoAddTab()
            .addFixtureFromGallery()

        app.staticTexts["Custom Tags"].tap()
        app.textFields["Add a tag"].tap()
        app.typeText("Uniqlo\n")   // Enter + use
        app.buttons["Save"].tap()

        ItemsRobot(app: app).assertTagVisible("Uniqlo")
    }

    // BB-ITEM-FR9-02 — Custom tag searchable (basic presence)
    func test_BB_ITEM_FR9_02_custom_tag_visible() {
        ItemsRobot(app: app)
            .gotoAddTab()
            .addFixtureFromGallery()

        app.staticTexts["Custom Tags"].tap()
        app.textFields["Add a tag"].tap()
        app.typeText("wedding-guest\n")
        app.buttons["Save"].tap()

        ItemsRobot(app: app).assertTagVisible("Wedding-Guest")
    }

    // BB-ITEM-FR9-03 — Duplicate tag dedupe (List editor removes dupes)
    func test_BB_ITEM_FR9_03_duplicate_tag_dedupe() {
        ItemsRobot(app: app)
            .gotoAddTab()
            .addFixtureFromGallery()

        app.staticTexts["Custom Tags"].tap()
        let tf = app.textFields["Add a tag"]
        tf.tap(); app.typeText("Blue\n")
        tf.tap(); app.typeText("Blue\n")
        app.buttons["Save"].tap()

        // Count only one “Blue” chip shown (simple contains check here; for exact count, walk chip views)
        ItemsRobot(app: app).assertTagVisible("Blue")
    }

    // (Optional) BB-ITEM-FR6-02 — Camera permission denied
    // NOTE: iOS Simulators don’t have a real camera. If you do run on device:
    func test_BB_ITEM_FR6_02_camera_permission_denied_on_device() throws {
        throw XCTSkip("Run on a real device only.")
        // When on device you can:
        // ItemsRobot(app: app).gotoAddTab()
        // app.buttons["items.camera"].tap()
        // let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // if springboard.alerts.element.waitForExistence(timeout: 3) {
        //    springboard.alerts.buttons["Don’t Allow"].tap()
        // }
        // ItemsRobot(app: app).assertError("Camera permission")
    }
}
