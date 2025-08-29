//
//  CO2AnalyticsTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//

import XCTest
@testable import myFinalProject

final class CO2AnalyticsTests: XCTestCase {

    func testMonthsBackProducesMonthStarts() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2025-08-26T12:00:00Z")!

        let months = CO2Analytics.monthsBack(from: now, count: 6, cal: cal)
        XCTAssertEqual(months.count, 6)

        // All are day 1, midnight UTC
        for m in months {
            let c = cal.dateComponents([.day, .hour, .minute, .second], from: m)
            XCTAssertEqual(c.day, 1); XCTAssertEqual(c.hour, 0); XCTAssertEqual(c.minute, 0); XCTAssertEqual(c.second, 0)
        }

        // Increasing order
        XCTAssertTrue(months[0] < months[1] && months[4] < months[5])
    }

    func testCumulative() {
        XCTAssertEqual(CO2Analytics.cumulative([1,2,3,0]), [1,3,6,6])
        XCTAssertEqual(CO2Analytics.cumulative([]), [])
    }

    func testSnapToMonthStart() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let d = ISO8601DateFormatter().date(from: "2025-08-31T23:59:59Z")!
        let s = CO2Analytics.snapToMonthStart(d, cal: cal)
        let c = cal.dateComponents([.day, .hour], from: s)
        XCTAssertEqual(c.day, 1)
        XCTAssertEqual(c.hour, 0)
    }

    func testCSV_CO2_HeaderAndFormat() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2025-08-15T10:00:00Z")!
        let months = CO2Analytics.monthsBack(from: now, count: 3, cal: cal)
        let csv = CO2Analytics.makeCSV(months: months, series: [0.8, 1.6, 2.4], isCO2: true, cal: cal)

        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "month,kg_co2_saved")
        XCTAssertTrue(lines[1].matches(#"^\d{4}-\d{2},\d+\.\d{3}$"#))
        XCTAssertEqual(lines.count, 4)
    }

    func testCSV_Outfits_HeaderAndFormat() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2025-08-15T10:00:00Z")!
        let months = CO2Analytics.monthsBack(from: now, count: 2, cal: cal)
        let csv = CO2Analytics.makeCSV(months: months, series: [10, 12], isCO2: false, cal: cal)
        XCTAssertTrue(csv.hasPrefix("month,outfits"))
    }
}

private extension String {
    func matches(_ pattern: String) -> Bool {
        range(of: pattern, options: .regularExpression) != nil
    }
}

