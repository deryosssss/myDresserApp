//
//  CO2SettingsStoreTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//

import XCTest
@testable import myFinalProject

final class CO2SettingsStoreTests: XCTestCase {

    func testSimpleModeClampsNegativeToZero() {
        let s = CO2SettingsStore()
        s.simplePerOutfit = -1
        s.mode = .simple
        XCTAssertEqual(s.estimatedKgPerOutfit, 0)
    }

    func testAdvancedFormulaPositive() {
        let s = CO2SettingsStore()
        s.mode = .advanced
        s.displacement = 0.3
        s.productionKg = 12
        s.avgWearsPerPurchase = 30
        s.laundryKg = 0.1
        // 0.3*(12/30) - 0.1 = 0.02
        XCTAssertEqual(s.estimatedKgPerOutfit, 0.02, accuracy: 0.0001)
    }

    func testAdvancedClampedAtZero() {
        let s = CO2SettingsStore()
        s.mode = .advanced
        s.displacement = 0.3
        s.productionKg = 10
        s.avgWearsPerPurchase = 50
        s.laundryKg = 0.3 // dominates
        XCTAssertEqual(s.estimatedKgPerOutfit, 0, accuracy: 0.0001)
    }

    func testAdvancedGuardAvgWearsZeroActsLikeOne() {
        let s = CO2SettingsStore()
        s.mode = .advanced
        s.displacement = 1
        s.productionKg = 10
        s.avgWearsPerPurchase = 0
        s.laundryKg = 0
        let zero = s.estimatedKgPerOutfit
        s.avgWearsPerPurchase = 1
        let one = s.estimatedKgPerOutfit
        XCTAssertEqual(zero, one, accuracy: 0.0001)
    }
}
