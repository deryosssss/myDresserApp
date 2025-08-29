//
//  RecoPromptTest.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//


import XCTest

@MainActor
final class RecoPromptTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
        NavRobot(app: app).gotoDressMe()
    }

    // BB-RECO-FR11-01 — Daily AI recommendation (Prompt)
    func test_BB_RECO_FR11_01_prompt_all_black_returns_full_outfit_with_shoes() {
        RecoRobot(app: app)
            .typePrompt("all black outfit")
            .tapCreate()
            .assertFullOutfitPresent()
    }

    // BB-RECO-FR11-02 — Weather-aware suggestion (rain)
    func test_BB_RECO_FR11_02_weather_rain_includes_outerwear_and_avoids_sandals() {
        RecoRobot(app: app)
            .setContextRain()
            .typePrompt("outfit based on weather")
            .tapCreate()
            .assertFullOutfitPresent()
            .assertShoesAreNotSandalsIfRain()
    }

    // BB-RECO-FR11-03 — No items available
    func test_BB_RECO_FR11_03_empty_wardrobe_shows_empty_state() {
        // Launch with explicit flag if your app supports clearing wardrobe in UTs
        app.terminate()
        app.launchArguments = ["UI_TEST_MODE=1", "--clearWardrobe=1"]
        app.launch()
        NavRobot(app: app).gotoDressMe()

        RecoRobot(app: app).typePrompt("anything").tapCreate()
        XCTAssertTrue(app.staticTexts["reco.empty"].waitForExistence(timeout: 6), "Empty state not shown")
    }

    // BB-RECO-FR11-04 — Colour binding to layer (red heels)
    func test_BB_RECO_FR11_04_neutral_with_red_heels_binds_colour_to_shoes() {
        RecoRobot(app: app)
            .typePrompt("neutral outfit with red heels")
            .tapCreate()
            .assertFullOutfitPresent()
        // Check shoe color chip or label
        XCTAssertTrue(app.staticTexts["reco.slot.shoes.color"].label.localizedCaseInsensitiveContains("red"))
    }

    // BB-RECO-FR11-05 — Dress base bias
    func test_BB_RECO_FR11_05_red_dress_minimal_prefers_dress_base() {
        RecoRobot(app: app).typePrompt("red dress minimal").tapCreate()
        XCTAssertTrue(app.images["reco.slot.dress.image"].waitForExistence(timeout: 6), "Dress not used")
    }

    // BB-RECO-FR11-06 — Top + Bottom base bias
    func test_BB_RECO_FR11_06_jeans_and_sneakers_casual_prefers_top_bottom() {
        RecoRobot(app: app).typePrompt("jeans and sneakers casual").tapCreate()
        XCTAssertTrue(app.images["reco.slot.top.image"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.images["reco.slot.bottom.image"].waitForExistence(timeout: 2))
        let shoeSubtype = app.staticTexts["reco.slot.shoes.subtype"]
        if shoeSubtype.waitForExistence(timeout: 2) {
            XCTAssertTrue(shoeSubtype.label.localizedCaseInsensitiveContains("sneaker"))
        }
    }

    // BB-RECO-FR11-07 — Soft-match note when strict colour unavailable
    func test_BB_RECO_FR11_07_soft_match_note_appears() {
        // Optional flag to remove black tops for UT
        app.terminate()
        app.launchArguments = ["UI_TEST_MODE=1", "--removeColor=black:top"]
        app.launch()
        NavRobot(app: app).gotoDressMe()

        RecoRobot(app: app).typePrompt("all black outfit").tapCreate().assertSoftMatchNoteVisible()
    }

    // BB-RECO-FR11-08 — Skip replaces one card
    func test_BB_RECO_FR11_08_skip_replaces_one_card_deck_size_stable() {
        RecoRobot(app: app).typePrompt("smart casual").tapCreate().skipFirstCardAndAssertReplaced()
    }

    // BB-RECO-FR11-09 — Save persists
    func test_BB_RECO_FR11_09_save_persists() {
        RecoRobot(app: app).typePrompt("date night").tapCreate().saveFirstCard(name: "UT Date Night")
        // Smoke: success toast already asserted
    }
}
