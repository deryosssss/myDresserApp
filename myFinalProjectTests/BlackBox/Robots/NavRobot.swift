//
//  NavRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest

struct NavRobot {
    let app: XCUIApplication

    @discardableResult func gotoWardrobe() -> Self {
        if app.tabBars.buttons["Wardrobe"].firstMatch.exists { app.tabBars.buttons["Wardrobe"].tap() }
        else if app.buttons["tab.wardrobe"].firstMatch.exists { app.buttons["tab.wardrobe"].tap() }
        else { app.buttons["Wardrobe"].firstMatch.tap() }
        XCTAssertTrue(app.otherElements["wardrobe.screen"].waitForExistence(timeout: 6), "Wardrobe not visible")
        return self
    }

    @discardableResult func gotoDressMe() -> Self {
        if app.tabBars.buttons["Dress Me"].firstMatch.exists { app.tabBars.buttons["Dress Me"].tap() }
        else if app.buttons["tab.dressme"].firstMatch.exists { app.buttons["tab.dressme"].tap() }
        else { app.buttons["Dress Me"].firstMatch.tap() }
        XCTAssertTrue(app.otherElements["dressme.screen"].waitForExistence(timeout: 8), "Dress Me not visible")
        return self
    }

    @discardableResult func gotoManual() -> Self {
        if app.tabBars.buttons["Manual"].firstMatch.exists { app.tabBars.buttons["Manual"].tap() }
        else if app.buttons["tab.manual"].firstMatch.exists { app.buttons["tab.manual"].tap() }
        else { app.buttons["Manual"].firstMatch.tap() }
        XCTAssertTrue(app.otherElements["manual.screen"].waitForExistence(timeout: 8), "Manual not visible")
        return self
    }

    @discardableResult func gotoWeather() -> Self {
        if app.tabBars.buttons["Weather"].firstMatch.exists { app.tabBars.buttons["Weather"].tap() }
        else if app.buttons["tab.weather"].firstMatch.exists { app.buttons["tab.weather"].tap() }
        else { app.buttons["Weather"].firstMatch.tap() }
        XCTAssertTrue(app.otherElements["weather.screen"].waitForExistence(timeout: 8), "Weather not visible")
        return self
    }
}
