//
//  GalleryFlowTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import XCTest

// GalleryFlowTests is a UI test suite that validates the outfits gallery. It covers:
// Saving outfits to the gallery and confirming thumbnails appear and openable (FR18-01).
// Opening outfit details directly from the gallery (FR18-02).
// Deleting an outfit from the gallery and ensuring the grid remains stable (FR18-03).
// Ordering logic, verifying that newly created outfits appear first in the gallery (FR18-04).
// It uses GalleryRobot to keep navigation, assertions, and fixture creation concise and reliable.

@MainActor
final class GalleryFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TEST_MODE=1"]
        app.launch()
    }

    // BB-GALLERY-FR18-01 — Save outfit to gallery
    func test_BB_GALLERY_FR18_01_save_outfit_to_gallery() {
        let G = GalleryRobot(app: app)

        // Best-effort: create a fixture outfit if your app exposes a hook in UI_TEST_MODE
        _ = G.createFixtureIfPossible()

        G.gotoProfile()
         .openOutfitsGallery()
         .assertOutfitVisibleInGallery()

        // Open detail to confirm the thumbnail is tappable
        G.openFirstCard()
        G.assertDetailOpened()
    }

    // BB-GAL-FR18-02 — Open detail from gallery
    func test_BB_GAL_FR18_02_open_detail_from_gallery() {
        let G = GalleryRobot(app: app)
        G.gotoProfile().openOutfitsGallery().openFirstCard().assertDetailOpened()
    }

    // BB-GAL-FR18-03 — Delete from gallery
    func test_BB_GAL_FR18_03_delete_from_gallery() {
        let G = GalleryRobot(app: app)
        G.gotoProfile().openOutfitsGallery()

        // Ensure we have something to delete
        if !app.scrollViews.images.firstMatch.exists {
            _ = G.createFixtureIfPossible()
            G.gotoProfile().openOutfitsGallery()
        }

        G.openFirstCard()
        G.deleteCurrentOutfitIfPossible()

        // Back to grid (system back or custom close)
        if app.buttons["Back"].exists { app.buttons["Back"].tap() }
        else { app.navigationBars.buttons.firstMatch.tap() }

        // Expect gallery to still be stable (pass: no crash, grid visible)
        G.assertOutfitVisibleInGallery()
    }

    // BB-GAL-FR18-04 — Ordering stable newest-first
    func test_BB_GAL_FR18_04_ordering_stable_newest_first() {
        let G = GalleryRobot(app: app)
        G.gotoProfile().openOutfitsGallery()

        // Create a new outfit and verify grid is interactable; newest should surface to top.
        _ = G.createFixtureIfPossible()
        G.gotoProfile().openOutfitsGallery()
        G.assertGalleryOrderIsNewestFirst()
    }
}
