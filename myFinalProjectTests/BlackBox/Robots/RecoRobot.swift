//
//  RecoRobot.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest

struct RecoRobot {
    let app: XCUIApplication

    // PROMPT
    @discardableResult func typePrompt(_ text: String) -> Self {
        let tf = app.textFields["reco.prompt.input"].firstMatch
        XCTAssertTrue(tf.waitForExistence(timeout: 8), "Prompt field missing")
        tf.tap(); tf.typeText(text)
        return self
    }

    @discardableResult func tapCreate() -> Self {
        let b = app.buttons["reco.prompt.create"]
        XCTAssertTrue(b.waitForExistence(timeout: 6), "Create button missing")
        b.tap()
        return self
    }

    @discardableResult func setContextRain() -> Self {
        let rain = app.buttons["reco.context.rain"]
        if rain.waitForExistence(timeout: 2) { rain.tap() }
        return self
    }

    // CARDS
    func cardCount() -> Int {
        app.otherElements.matching(identifier: "reco.card").count
    }

    func assertAtLeastOneCard() {
        XCTAssertTrue(app.otherElements.matching(identifier: "reco.card")
                        .firstMatch.waitForExistence(timeout: 10), "No recommendation cards")
    }

    func assertFullOutfitPresent() {
        assertAtLeastOneCard()
        // Either Dress+Shoes OR Top+Bottom(+Outerwear)+Shoes
        let hasShoes = app.images["reco.slot.shoes.image"].firstMatch.waitForExistence(timeout: 4)
        XCTAssertTrue(hasShoes, "Footwear not included")
        let hasDress = app.images["reco.slot.dress.image"].firstMatch.exists
        let hasTopBottom = app.images["reco.slot.top.image"].firstMatch.exists && app.images["reco.slot.bottom.image"].firstMatch.exists
        XCTAssertTrue(hasDress || hasTopBottom, "Neither Dress nor Top+Bottom were present")
    }

    func assertShoesAreNotSandalsIfRain() {
        // Your cell should expose a label for shoe subtype
        let shoeLabel = app.staticTexts["reco.slot.shoes.subtype"]
        if shoeLabel.waitForExistence(timeout: 1) {
            XCTAssertFalse(shoeLabel.label.localizedCaseInsensitiveContains("sandal"),
                           "Sandals chosen while raining")
        }
    }

    func assertSoftMatchNoteVisible() {
        let note = app.staticTexts["reco.note.softmatch"]
        XCTAssertTrue(note.waitForExistence(timeout: 6), "Soft-match note not shown")
    }

    // ACTIONS
    @discardableResult func skipFirstCardAndAssertReplaced() -> Self {
        assertAtLeastOneCard()
        let before = cardCount()
        let first = app.otherElements.matching(identifier: "reco.card").firstMatch
        let skip = first.buttons["reco.card.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 4), "Skip not present")
        skip.tap()

        // Wait for the previous card to disappear and a new one to show
        XCTAssertTrue(first.waitForNonExistence(timeout: 8), "Old card didn’t disappear")
        XCTAssertEqual(cardCount(), before, "Deck size changed after skip")
        return self
    }

    @discardableResult func saveFirstCard(name: String = "My Outfit") -> Self {
        let first = app.otherElements.matching(identifier: "reco.card").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 6), "No card to save")
        let save = first.buttons["reco.card.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 6), "Save not present on card")
        save.tap()

        let nameField = app.textFields["outfit.save.name"]
        if nameField.waitForExistence(timeout: 2) {
            nameField.tap(); nameField.typeText(name)
        }
        app.buttons["outfit.save.confirm"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["reco.saved.toast"].waitForExistence(timeout: 6), "No success toast")
        return self
    }
}
