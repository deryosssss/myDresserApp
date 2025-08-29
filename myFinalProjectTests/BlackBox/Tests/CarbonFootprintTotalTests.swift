//
//  CarbonFootprintTotalTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest

@MainActor
final class CarbonFootprintTotalTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]   // enables test hooks
        app.launch()
    }

    /// BB-UX-FR27-02 — Wardrobe footprint total matches sum of item estimatedFootprintKg (active only).
    func test_BB_UX_FR27_02_WardrobeFootprintTotal() {
        let R = CO2Robot(app: app)

        // 1) Open the Analytics/Dashboard where total is shown
        R.goToProfile().openStatsDashboard()

        // 2) Read the UI total (kg) with units
        let uiTotal = R.readWardrobeTotalKg()

        // 3) Export raw items -> compute expected sum (exclude archived)
        let items = R.exportWardrobeJSON()
        let expected = R.expectedActiveTotal(from: items)

        // 4) Compare with same precision as UI (assume 2 decimals) and tolerance ≤ 0.01 kg
        let uiRounded = (uiTotal * 100).rounded() / 100
        let expRounded = (expected * 100).rounded() / 100
        let diff = abs(uiRounded - expRounded)

        XCTAssertLessThanOrEqual(
            diff, 0.01,
            "Wardrobe footprint total mismatch. UI \(uiRounded) kg vs expected \(expRounded) kg (diff \(diff))"
        )
    }
}
