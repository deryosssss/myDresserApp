//
//  DetailRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//


import XCTest

struct DetailRobot {
    let app: XCUIApplication

    // NAV
    @discardableResult func openFirstItem() -> Self {
        let first = app.cells["wardrobe.cell.0"].firstMatch
        if !first.exists {
            // fallback
            XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 6), "No items in wardrobe")
            app.cells.firstMatch.tap()
        } else {
            first.tap()
        }
        XCTAssertTrue(app.otherElements["item.detail.screen"].waitForExistence(timeout: 6), "Item detail not visible")
        return self
    }

    // TABS
    @discardableResult func gotoAbout() -> Self { app.buttons["detail.tab.about"].tap(); return self }
    @discardableResult func gotoOutfits() -> Self { app.buttons["detail.tab.outfits"].tap(); return self }
    @discardableResult func gotoStats() -> Self { app.buttons["detail.tab.stats"].tap(); return self }

    // EDIT
    @discardableResult func editSize(_ size: String, brand: String) -> Self {
        app.buttons["detail.edit"].tap()
        let sizeTF = app.textFields["edit.size"]
        XCTAssertTrue(sizeTF.waitForExistence(timeout: 4))
        sizeTF.tap(); sizeTF.clearAndType(size)

        let brandTF = app.textFields["edit.brand"]
        XCTAssertTrue(brandTF.waitForExistence(timeout: 4))
        brandTF.tap(); brandTF.clearAndType(brand)

        app.buttons["edit.save"].tap()
        return self
    }

    @discardableResult func replacePhotoWithFixture() -> Self {
        app.buttons["detail.replacePhoto"].tap()
        // reuse your fixture button from item add flow
        let b = app.buttons["items.addFixture"]
        XCTAssertTrue(b.waitForExistence(timeout: 6), "Fixture button missing")
        b.tap()
        XCTAssertTrue(app.otherElements["replace.success"].waitForExistence(timeout: 8), "No success indicator")
        return self
    }

    @discardableResult func createOutfitWithAI() -> Self {
        app.buttons["detail.createAI"].tap()
        XCTAssertTrue(app.otherElements["dressme.screen"].waitForExistence(timeout: 6))
        return self
    }

    // STATS
    @discardableResult func editLastWorn(daysAgo: Int) -> Self {
        gotoStats()
        app.buttons["stats.lastworn.edit"].tap()
        // adjust date using picker (assume day wheel is available)
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 4))
        // simple: just tap save (tests rely on control itself)
        app.buttons["stats.lastworn.save"].tap()
        return self
    }

    func assertUnderusedVisible() {
        gotoStats()
        XCTAssertTrue(app.staticTexts["stats.badge.underused"].waitForExistence(timeout: 4))
    }

    func assertOutfitsCountPositiveAndNavigates() {
        gotoOutfits()
        let cell = app.cells["outfit.cell.0"]
        XCTAssertTrue(cell.waitForExistence(timeout: 6), "No outfits in grid")
        cell.tap()
        XCTAssertTrue(app.otherElements["outfit.detail.screen"].waitForExistence(timeout: 6), "Did not navigate to outfit detail")
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        if let stringValue = value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            typeText(deleteString)
        }
        typeText(text)
    }
}
