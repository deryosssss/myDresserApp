//
//  ManualRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//
// XCUITest helper for the manual outfit builder. It automates choosing preset layouts (e.g. top–bottom–shoes, with/without outerwear), rolling outfit suggestions, and locking/unlocking layers. It also provides assertions to check the correct carousels are shown, that saving is disabled until valid, and that locked layers prevent scrolling — making manual outfit flow tests more reliable and concise.


import XCTest

struct ManualRobot {
    let app: XCUIApplication

    // PRESET
    @discardableResult func choosePresetTopBottomShoes() -> Self {
        let b = app.buttons["manual.preset.tbs"]
        (b.exists ? b : app.segmentedControls.buttons["3"]).tap()
        return self
    }

    @discardableResult func choosePresetPlusOuterwear() -> Self {
        let b = app.buttons["manual.preset.outerwear"]
        (b.exists ? b : app.segmentedControls.buttons["4"]).tap()
        return self
    }

    // ASSERTIONS
    func assertCarousels(_ ids: [String]) {
        for id in ids {
            XCTAssertTrue(app.collectionViews[id].waitForExistence(timeout: 6), "Carousel \(id) missing")
        }
    }

    func assertDefaultPresetCarousels() {
        assertCarousels(["manual.carousel.top","manual.carousel.bottom","manual.carousel.shoes"])
    }

    func assertFourPresetCarousels() {
        assertCarousels(["manual.carousel.outerwear","manual.carousel.top","manual.carousel.bottom","manual.carousel.shoes"])
    }

    func assertSaveDisabled() {
        let save = app.buttons["manual.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 4))
        XCTAssertFalse(save.isEnabled, "Save should be disabled")
    }

    // ACTIONS
    @discardableResult func roll() -> Self {
        app.buttons["manual.roll"].firstMatch.tap()
        return self
    }

    @discardableResult func lock(_ layer: String) -> Self {
        app.buttons["manual.lock.\(layer)"].firstMatch.tap()
        return self
    }

    @discardableResult func unlock(_ layer: String) -> Self {
        app.buttons["manual.lock.\(layer)"].firstMatch.tap()
        return self
    }

    func assertLayerLockedPreventsGesture(_ layerId: String) {
        let cv = app.collectionViews[layerId]
        XCTAssertTrue(cv.waitForExistence(timeout: 4))
        let start = cv.cells.firstMatch.frame
        cv.swipeLeft()
        // If locked, index should snap back (heuristic: frame unchanged)
        XCTAssertEqual(cv.cells.firstMatch.frame.origin.x, start.origin.x, accuracy: 1.0, "Locked layer scrolled")
    }
}
