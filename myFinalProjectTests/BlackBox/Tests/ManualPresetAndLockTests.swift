//
//  ManualPresetAndLockTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//
// ManualPresetAndLockTests is a UI test suite for the manual outfit builder. It verifies:
// Presets: default Top+Bottom+Shoes preset shows 3 carousels (FR12-01), and switching to +Outerwear shows 4 (FR12-02).
// Save validation: saving is blocked if shoes are missing (FR12-03).
// Locking: locking a layer (e.g., top) keeps it fixed across shuffles (FR16-01), unlocking allows changes (FR16-02), and locked layers prevent swipe gestures (FR16-03).
// It uses ManualRobot to simplify preset, lock, and roll interactions in tests.

import XCTest

@MainActor
final class ManualPresetAndLockTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
        NavRobot(app: app).gotoManual()
    }

    // BB-MANUAL-FR12-01 — Top + Bottom + Shoes preset
    func test_BB_MANUAL_FR12_01_default_preset_has_three_carousels() {
        ManualRobot(app: app).choosePresetTopBottomShoes().assertDefaultPresetCarousels()
        // Save disabled until all selected
        ManualRobot(app: app).assertSaveDisabled()
    }

    // BB-MANUAL-FR12-02 — Apply different preset (+Outerwear)
    func test_BB_MANUAL_FR12_02_switch_to_four_layers() {
        ManualRobot(app: app).choosePresetPlusOuterwear().assertFourPresetCarousels()
    }

    // BB-MANUAL-FR12-03 — Save validation needs shoes
    func test_BB_MANUAL_FR12_03_save_validation_needs_shoes() {
        // Intentionally leave shoes unselected
        let save = app.buttons["manual.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 4))
        save.tap()
        XCTAssertTrue(app.staticTexts["manual.validation.needShoes"].waitForExistence(timeout: 4))
    }

    // BB-LOCK-FR16-01 — Lock one item & shuffle
    func test_BB_LOCK_FR16_01_lock_top_and_roll_keeps_top() {
        let top = app.collectionViews["manual.carousel.top"].cells.firstMatch
        XCTAssertTrue(top.waitForExistence(timeout: 6))
        let before = top.identifier
        ManualRobot(app: app).lock("top").roll().roll()
        XCTAssertEqual(app.collectionViews["manual.carousel.top"].cells.firstMatch.identifier, before, "Locked top changed")
    }

    // BB-LOCK-FR16-02 — Clear lock then roll
    func test_BB_LOCK_FR16_02_unlock_top_then_roll_changes_top() {
        ManualRobot(app: app).unlock("top")
        let top = app.collectionViews["manual.carousel.top"].cells.firstMatch
        let before = top.identifier
        ManualRobot(app: app).roll()
        XCTAssertNotEqual(app.collectionViews["manual.carousel.top"].cells.firstMatch.identifier, before, "Top did not change after unlock/roll")
    }

    // BB-LOCK-FR16-03 — Carousel lock prevents input
    func test_BB_LOCK_FR16_03_locked_layer_prevents_gesture() {
        ManualRobot(app: app).lock("bottom").assertLayerLockedPreventsGesture("manual.carousel.bottom")
    }
}
