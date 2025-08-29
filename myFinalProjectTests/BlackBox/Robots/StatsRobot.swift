//
//  StatsRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//
// XCUITest helper for the stats dashboard. It automates navigation to the My Stats screen, then provides assertions to:
// Check that distribution charts (categories, colour) and usage sections (most/least worn) render.
// Verify the zero-data state (no items/outfits).
// Test interactive chart behavior, like tapping a legend pill to open the drill-down sheet or toggling the donut chart’s center label between hints and percentages.

import XCTest

@MainActor
struct StatsRobot {
    let app: XCUIApplication

    // MARK: - Nav

    @discardableResult
    func gotoProfile() -> Self {
        app.buttons["Profile"].firstMatch.tap()
        return self
    }

    @discardableResult
    func openStats() -> Self {
        let btn = app.staticTexts["My Stats"]
        XCTAssertTrue(btn.waitForExistence(timeout: 6), "Profile → My Stats not found")
        btn.tap()
        XCTAssertTrue(app.staticTexts["My Stats"].waitForExistence(timeout: 6), "StatsView not visible")
        return self
    }

    // MARK: - Assertions

    func assertDistributionChartsRender() {
        XCTAssertTrue(app.staticTexts["Categories"].waitForExistence(timeout: 6), "Categories section not visible")
        XCTAssertTrue(app.staticTexts["Colour"].waitForExistence(timeout: 6), "Colour section not visible")
    }

    func assertUsageSectionsPresent() {
        XCTAssertTrue(app.staticTexts["Most worn items"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Least worn items"].waitForExistence(timeout: 6))
    }

    func assertZeroDataState() {
        XCTAssertTrue(app.staticTexts["No items yet"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["No outfits yet"].waitForExistence(timeout: 6))
    }

    // MARK: - Legend / drilldown

    /// Taps the first legend pill in the currently visible donut and asserts a sheet opens.
    func tapFirstLegendAndAssertSheet() {
        // Legend pill buttons' accessibility label aggregates like "Top • 4".
        // Match on the bullet to avoid other buttons.
        let legendButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS '•'"))
            .firstMatch
        XCTAssertTrue(legendButton.waitForExistence(timeout: 6), "No legend button found")

        // Capture the *first* child static text (segment label, e.g. "Top")
        let labelText = legendButton.staticTexts.element(boundBy: 0).label
        legendButton.tap()

        // ItemGridSheet uses navigationTitle = label
        let title = app.staticTexts[labelText]
        XCTAssertTrue(title.waitForExistence(timeout: 6), "Drill-down sheet/title '\(labelText)' not visible")
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 6), "Drill-down content not visible")
    }

    /// Verifies center label toggles between “All/Tap a slice” and a concrete % when tapping any slice/legend.
    func assertCenterLabelSelectionBehavior() {
        // Initial center helper texts
        let anyAll    = app.staticTexts["All"]
        let anyPrompt = app.staticTexts["Tap a slice"]
        XCTAssertTrue(anyAll.exists || anyPrompt.exists, "Center hint not shown")

        // Tap first legend (match by bullet)
        let btn = app.buttons
            .matching(NSPredicate(format: "label CONTAINS '•'"))
            .firstMatch
        XCTAssertTrue(btn.waitForExistence(timeout: 6), "No legend button to tap")
        btn.tap()

        // Expect a percent label to be present (e.g., “23%”)
        let percent = app.staticTexts
            .matching(NSPredicate(format: "label MATCHES '[0-9]{1,3}%'"))
            .firstMatch
        XCTAssertTrue(percent.waitForExistence(timeout: 6), "Center % not shown after selection")

        // Tap same legend again to clear
        btn.tap()
        XCTAssertTrue(anyAll.exists || anyPrompt.exists, "Center hint didn’t reset after clearing")
    }
}
