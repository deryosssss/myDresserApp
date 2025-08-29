//
//  UIT_UIRegressionTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//
//  Covers:
//  • BB-UI-UIR1-01  Responsive layouts (rotation + Dynamic Type)
//  • BB-UI-UIR2-01  Item tiles show thumbnail + labels
//  • BB-UI-UIR4-01  Consistent navigation (tab/back)
//  • BB-UI-UIR9-01  Dark mode
//

import XCTest

final class UIT_UIRegressionTests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: BB-UI-UIR1-01 — Responsive layouts

    func testResponsiveLayouts_RotateAndDynamicType() {
        // Launch with larger Dynamic Type for stress (XL is readable but pushes layout)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXL"]
        app.launch()

        // Test a few main screens (adjust labels to your tab titles if needed)
        openTab(named: "Home")
        assertCoreControlsVisible(screen: "Home")

        rotate(.landscapeLeft);  attachShot("Home-landscape")
        rotate(.portrait);       attachShot("Home-portrait")

        openTab(named: "Wardrobe")
        assertCoreControlsVisible(screen: "Wardrobe")
        rotate(.landscapeRight); attachShot("Wardrobe-landscape")
        rotate(.portrait);       attachShot("Wardrobe-portrait")

        // Open Analytics if present
        if tabBarButton("Profile").exists { // example: go via Profile → My Stats
            openTab(named: "Profile")
            app.buttons["My Stats"].firstMatch.tap()
            assertBackButton()
            attachShot("Stats-portrait")
            rotate(.landscapeLeft); attachShot("Stats-landscape")
            rotate(.portrait)
            app.navigationBars.buttons.element(boundBy: 0).tap() // Back
        }
    }

    // MARK: BB-UI-UIR2-01 — Item tiles show thumbnail + labels

    func testWardrobeTiles_ShowThumbnailAndLabels() {
        app.launch()
        openTab(named: "Wardrobe")

        // Prefer explicit identifiers if available, else fall back to generic queries.
        let grid = app.otherElements["WardrobeGrid"].firstMatch
        let hasGrid = grid.exists

        let cells = hasGrid ? grid.descendants(matching: .other).matching(identifier: "WardrobeItemCell")
                            : app.images // fallback: AsyncImage renders as .image

        // Expect at least one visible tile/thumbnail
        XCTAssertTrue(cells.firstMatch.waitForExistence(timeout: 5), "No item cells / images found")

        // If you expose labels (e.g., category/brand) check they’re hittable
        let anyLabel = app.staticTexts["WardrobeItemLabel"].firstMatch
        if anyLabel.exists { XCTAssertTrue(anyLabel.isHittable, "Label not visible on tile") }

        attachShot("Wardrobe-grid")
    }

    // MARK: BB-UI-UIR4-01 — Consistent navigation

    func testNavigationConsistency_TabBarAndBack() {
        app.launch()

        // Home → Wardrobe → Filters → Back
        openTab(named: "Home")
        openTab(named: "Wardrobe")

        // Open Filters sheet if button exists
        if app.buttons["Filter"].exists {
            app.buttons["Filter"].tap()
            XCTAssertTrue(app.navigationBars["Filter"].exists, "Filter sheet did not open")
            app.buttons["xmark"].firstMatch.tap() // close via leading toolbar (WardrobeFilterView)
        }

        // Go into an item detail, back out
        if app.images.firstMatch.waitForExistence(timeout: 5) {
            app.images.firstMatch.tap()
            assertBackButton()
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Ensure Tab Bar still present and responsive
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Tab bar missing")
        openTab(named: "Profile") // sanity hop
        XCTAssertTrue(app.staticTexts["My account details"].exists || app.buttons["My account details"].exists)
    }

    // MARK: BB-UI-UIR9-01 — Dark mode

    func testDarkMode_AcrossMainScreens() {
        // Use an opt-in launch argument that your SwiftUI App can read to force .dark
        app.launchArguments += ["-ui_testing_dark"]
        // Also pass the system flag some stacks honor automatically:
        app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        app.launch()

        openTab(named: "Home");     attachShot("Dark-Home")
        openTab(named: "Wardrobe"); attachShot("Dark-Wardrobe")
        if tabBarButton("Profile").exists {
            openTab(named: "Profile"); attachShot("Dark-Profile")
        }

        // Smoke assertion: important button is hittable in dark
        if app.buttons["Filter"].exists {
            XCTAssertTrue(app.buttons["Filter"].isHittable, "Filter button not visible in dark mode")
        }
    }

    // MARK: - Helpers

    private func rotate(_ o: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = o
        // small settle time avoids false negatives immediately after rotation
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    private func openTab(named title: String) {
        let btn = tabBarButton(title)
        XCTAssertTrue(btn.waitForExistence(timeout: 4), "Tab \(title) not found")
        btn.tap()
    }

    private func tabBarButton(_ title: String) -> XCUIElement {
        app.tabBars.buttons[title]
    }

    private func assertCoreControlsVisible(screen: String) {
        // Ensure the tab bar is visible and tappable (no layout spill)
        XCTAssertTrue(app.tabBars.firstMatch.exists, "\(screen): Tab bar missing")
        XCTAssertTrue(app.tabBars.firstMatch.isHittable, "\(screen): Tab bar not hittable")
    }

    private func assertBackButton() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.exists, "Back button not present")
        XCTAssertTrue(back.isHittable, "Back button not hittable")
    }

    private func attachShot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
