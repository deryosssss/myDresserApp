//
//  WeatherRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//


import XCTest

struct WeatherRobot {
    let app: XCUIApplication

    func assertCardsAppear() {
        XCTAssertTrue(app.otherElements["weather.card"].firstMatch.waitForExistence(timeout: 8), "No weather cards")
    }

    func assertDressCodeLockedAfterFirstPick() {
        // tap a base choice, then verify lock icon
        app.otherElements["weather.base.choice"].firstMatch.tap()
        XCTAssertTrue(app.images["weather.base.lock"].waitForExistence(timeout: 4), "Dress code not locked")
    }

    func assertBootsPreferredIfRaining() {
        // shoe subtype label on first card
        let subtype = app.staticTexts["weather.slot.shoes.subtype"]
        if subtype.waitForExistence(timeout: 2) {
            XCTAssertTrue(subtype.label.localizedCaseInsensitiveContains("boot") ||
                          subtype.label.localizedCaseInsensitiveContains("boots"),
                          "Boots not preferred in rain")
        }
    }
}
