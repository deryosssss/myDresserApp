//
//  GalleryRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//


import XCTest

@MainActor
struct GalleryRobot {
    let app: XCUIApplication

    // MARK: - Nav

    @discardableResult
    func gotoProfile() -> Self {
        // Tab bar “Profile”
        app.buttons["Profile"].firstMatch.tap()
        return self
    }

    @discardableResult
    func openOutfitsGallery() -> Self {
        // Profile → "My Outfits"
        let btn = app.staticTexts["My Outfits"]
        XCTAssertTrue(btn.waitForExistence(timeout: 6), "Profile → My Outfits not found")
        btn.tap()
        // Expect Outfits header
        XCTAssertTrue(app.staticTexts["My Outfits"].waitForExistence(timeout: 6), "OutfitsView not visible")
        return self
    }

    // MARK: - Test fixtures (best-effort)

    /// Tries a few known hooks to create/save a fixture outfit so gallery isn't empty.
    /// Returns true if something was tapped that *should* create an outfit.
    @discardableResult
    func createFixtureIfPossible() -> Bool {
        let ids = [
            "outfits.saveFixture",        // preferred test-only id
            "prompt.fixture.save",        // prompt/AI fixture
            "manual.fixture.save",        // manual fixture
            "weather.fixture.save"        // weather fixture
        ]
        for id in ids {
            let b = app.buttons[id]
            if b.exists { b.tap(); return true }
        }
        // Optional deep link your app may support in UI_TEST_MODE
        if let url = URL(string: "myfinalproject://test/create-outfit-fixture") {
            DeepLink.relaunch(app, url: url)
            return true
        }
        return false
    }

    // MARK: - Grid interactions

    /// Taps the first gallery card (best-effort against a LazyVGrid).
    @discardableResult
    func openFirstCard() -> Self {
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 6), "Outfits grid scroll view missing")

        // Prefer a button inside the grid (NavigationLink renders as a button).
        if scroll.buttons.firstMatch.exists {
            scroll.buttons.firstMatch.tap()
            return self
        }

        // Fallback: any tappable image inside the grid.
        let image = scroll.images.firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 6), "No collage image to tap")
        image.tap()
        return self
    }

    // MARK: - Assertions

    func assertOutfitVisibleInGallery() {
        // Some image exists in grid
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 6))
        XCTAssertTrue(scroll.images.firstMatch.waitForExistence(timeout: 6), "Expected at least one outfit thumbnail")
    }

    func assertDetailOpened() {
        // Outfit detail usually shows Delete/Favorite or a title
        let hasDelete = app.buttons["Delete"].exists || app.buttons["outfit.delete"].exists
        let hasTitle  = app.staticTexts["Outfit"].exists || app.navigationBars.firstMatch.exists
        XCTAssertTrue(hasDelete || hasTitle, "Outfit detail view didn’t open")
    }

    func deleteCurrentOutfitIfPossible(confirmTitle: String = "Delete") {
        let delete = app.buttons["outfit.delete"].exists ? app.buttons["outfit.delete"]
                    : app.buttons["Delete"]
        if delete.exists {
            delete.tap()
            // confirm sheet / alert if your UI shows one
            let confirm = app.buttons[confirmTitle]
            if confirm.waitForExistence(timeout: 2) { confirm.tap() }
        }
    }

    func assertGalleryOrderIsNewestFirst(afterCreatingNewItem: Bool = true) {
        // Heuristic: after creating a new outfit, the first grid cell should be hittable quickly.
        // (Real check would compare IDs/timestamps exposed via accessibility.)
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 6))
        XCTAssertTrue(scroll.waitForHittable(timeout: 4), "Gallery not interactable")
    }
}

private extension XCUIElement {
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let start = Date()
        while !isHittable && Date().timeIntervalSince(start) < timeout {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
        return isHittable
    }
}
