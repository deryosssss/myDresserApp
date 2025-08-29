//
//  FilterNormalizationTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest

@MainActor
final class FilterNormalizationTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
    }

    // Helper to (lightly) edit color on first wardrobe item for alias tests
    private func retagFirstItemColor(_ color: String) {
        NavRobot(app: app).gotoWardrobe()
        DetailRobot(app: app).openFirstItem().gotoAbout()
        app.buttons["detail.edit"].tap()
        let colorTF = app.textFields["edit.color"]
        XCTAssertTrue(colorTF.waitForExistence(timeout: 4))
        colorTF.tap(); colorTF.clearAndType(color)
        app.buttons["edit.save"].tap()
    }

    // BB-FILTER-FR13-01 — Colour normalization — alias
    func test_BB_FILTER_FR13_01_charcoal_matches_grey_requests() {
        retagFirstItemColor("Charcoal")
        NavRobot(app: app).gotoDressMe()
        RecoRobot(app: app).typePrompt("grey outfit").tapCreate().assertFullOutfitPresent()
    }

    // BB-FILTER-FR13-02 — Colour normalization — prefix/suffix
    func test_BB_FILTER_FR13_02_prefix_suffix_normalises() {
        retagFirstItemColor("light brown")
        NavRobot(app: app).gotoDressMe()
        RecoRobot(app: app).typePrompt("brown outfit").tapCreate().assertFullOutfitPresent()

        retagFirstItemColor("bluish")
        NavRobot(app: app).gotoDressMe()
        RecoRobot(app: app).typePrompt("blue outfit").tapCreate().assertFullOutfitPresent()
    }

    // BB-FILTER-FR13-03 — Family expansion
    func test_BB_FILTER_FR13_03_beige_matches_camel_taupe() {
        retagFirstItemColor("camel")
        NavRobot(app: app).gotoDressMe()
        RecoRobot(app: app).typePrompt("beige outfit").tapCreate().assertFullOutfitPresent()
    }

    // BB-FILTER-FR13-04 — Subtype hard filter (boots)
    func test_BB_FILTER_FR13_04_black_boots_restricts_shoes_to_boots() {
        NavRobot(app: app).gotoDressMe()
        RecoRobot(app: app).typePrompt("black boots").tapCreate()
        let shoeSubtype = app.staticTexts["reco.slot.shoes.subtype"]
        XCTAssertTrue(shoeSubtype.waitForExistence(timeout: 6))
        XCTAssertTrue(shoeSubtype.label.localizedCaseInsensitiveContains("boot"), "Shoes not restricted to boots")
    }
}
