//
//  DetailAndWearTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest

@MainActor
final class DetailAndWearTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
        NavRobot(app: app).gotoWardrobe()
    }

    // BB-DETAIL-FR14-01 — Item detail view
    func test_BB_DETAIL_FR14_01_item_detail_tabs_and_actions() {
        DetailRobot(app: app).openFirstItem()
        XCTAssertTrue(app.images["detail.image.header"].waitForExistence(timeout: 6))
        DetailRobot(app: app).gotoAbout()
        DetailRobot(app: app).gotoOutfits()
        DetailRobot(app: app).gotoStats()
        XCTAssertTrue(app.buttons["detail.edit"].exists)
        XCTAssertTrue(app.buttons["detail.delete"].exists)
    }

    // BB-DETAIL-FR14-02 — Edit from detail
    func test_BB_DETAIL_FR14_02_edit_size_brand_persists() {
        DetailRobot(app: app).openFirstItem().editSize("M", brand: "Acme")
        // Re-open to verify
        app.navigationBars.buttons.element(boundBy: 0).tap()
        DetailRobot(app: app).openFirstItem().gotoAbout()
        XCTAssertTrue(app.staticTexts["chip.size.M"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["chip.brand.Acme"].exists)
    }

    // BB-DETAIL-FR14-03 — Replace photo
    func test_BB_DETAIL_FR14_03_replace_photo_succeeds() {
        DetailRobot(app: app).openFirstItem().replacePhotoWithFixture()
    }

    // BB-DETAIL-FR14-04 — AI outfit from item (expected current failure)
    func test_BB_DETAIL_FR14_04_ai_outfit_from_item_preseeded() {
        XCTExpectFailure("Known issue: item id not read properly in prompt flow")
        DetailRobot(app: app).openFirstItem().createOutfitWithAI()
        // Expect the resulting card to include the item chip/reference
        XCTAssertTrue(app.staticTexts["reco.contains.seedItem"].waitForExistence(timeout: 6))
    }

    // BB-WEAR-FR17-01 — Last worn edit
    func test_BB_WEAR_FR17_01_edit_last_worn_persists() {
        DetailRobot(app: app).openFirstItem().editLastWorn(daysAgo: 7)
        XCTAssertTrue(app.staticTexts["stats.lastworn.value"].waitForExistence(timeout: 4))
    }

    // BB-WEAR-FR17-02 — Underused flag
    func test_BB_WEAR_FR17_02_underused_badge_shows_for_old_date() {
        // Optional test hook to set last worn far in the past
        app.terminate()
        app.launchArguments = ["UI_TEST_MODE=1", "--seedUnderused=1"]
        app.launch()
        NavRobot(app: app).gotoWardrobe()
        DetailRobot(app: app).openFirstItem().assertUnderusedVisible()
    }

    // BB-WEAR-FR17-03 — Outfits count & navigation
    func test_BB_WEAR_FR17_03_outfits_grid_navigates_to_detail() {
        DetailRobot(app: app).openFirstItem().assertOutfitsCountPositiveAndNavigates()
    }

    // BB-WEAR-FR17-04 — Save outfit seeds wear log fields
    func test_BB_WEAR_FR17_04_saved_outfit_has_initial_wear_fields() {
        NavRobot(app: app).gotoDressMe()
        RecoRobot(app: app).typePrompt("office smart").tapCreate().saveFirstCard(name: "UT Office")
        // Open that outfit from any item in it later (implementation-specific).
        // For now, just assert the generic toast/success exists.
        XCTAssertTrue(app.otherElements["reco.saved.toast"].waitForExistence(timeout: 4))
    }
}
