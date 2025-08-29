//
//  CO2Robot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest
import UIKit

@MainActor
struct CO2Robot {
    let app: XCUIApplication

    // MARK: - Navigation

    @discardableResult
    func goToProfile() -> Self {
        app.buttons["Profile"].firstMatch.tap()
        return self
    }

    @discardableResult
    func openStatsDashboard() -> Self {
        let stats = app.staticTexts["My Stats"]
        XCTAssertTrue(stats.waitForExistence(timeout: 6), "Profile → My Stats not found")
        stats.tap()
        XCTAssertTrue(app.staticTexts["My Stats"].waitForExistence(timeout: 6), "StatsView not visible")
        return self
    }

    // MARK: - Reads

    /// Reads the "Wardrobe footprint total" label and parses the numeric kg value.
    func readWardrobeTotalKg() -> Double {
        let label = app.staticTexts["co2.wardrobe.total.value"]
        XCTAssertTrue(label.waitForExistence(timeout: 6), "Wardrobe footprint total label missing")

        let text = label.label   // e.g., "42.37 kg CO₂e"
        XCTAssertTrue(text.contains("kg"), "Units (kg) missing on total label")
        XCTAssertTrue(text.lowercased().contains("co₂"), "CO₂ unit missing on total label")

        let number = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                          .joined()
        return Double(number) ?? XCTFailAndReturn(0, "Could not parse number from '\(text)'")
    }

    /// Taps the test-only export button and returns parsed items (from UIPasteboard JSON).
    func exportWardrobeJSON() -> [ExportItem] {
        let button = app.buttons["test.export.wardrobe.json"]
        XCTAssertTrue(button.waitForExistence(timeout: 6), "Export button not available (UI_TEST_MODE?)")
        button.tap()

        guard let text = UIPasteboard.general.string,
              let data = text.data(using: .utf8) else {
            XCTFail("No JSON on pasteboard after export")
            return []
        }

        do {
            return try JSONDecoder().decode([ExportItem].self, from: data)
        } catch {
            XCTFail("Failed to decode export JSON: \(error)")
            return []
        }
    }

    // MARK: - Compute

    func expectedActiveTotal(from items: [ExportItem]) -> Double {
        items.filter { $0.archived != true }
             .compactMap { $0.estimatedFootprintKg }
             .reduce(0, +)
    }
}

struct ExportItem: Decodable {
    let id: String
    let estimatedFootprintKg: Double?
    let archived: Bool?
}

// Small helper to fail & keep type context
@discardableResult
func XCTFailAndReturn<T>(_ value: T, _ message: String) -> T {
    XCTFail(message)
    return value
}
