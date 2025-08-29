//
//  WearEventTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//
// WearEventTests is a unit test suite for wear logging on wardrobe items. It confirms that:
// Marking an item as worn increments wearCount and sets lastWorn to the current time.
// The operation is idempotent — if called twice in the same instant (e.g., double tap), it doesn’t double-increment the count.

import XCTest
@testable import myFinalProject

final class WearEventTests: XCTestCase {
    func testWearIncrementsAndSetsLastWorn() {
        var item = WardrobeItem(id:"1", name:"t", colour:"", tags:[], wearCount:0, lastWorn:nil)
        let now = Date(timeIntervalSince1970: 1_725_000_000)
        let clock = { now } // dependency-injected clock
        markWorn(&item, now: clock())

        XCTAssertEqual(item.wearCount, 1)
        XCTAssertEqual(item.lastWorn, now)
    }

    func testIdempotentDoubleTap() {
        var item = WardrobeItem(id:"1", name:"t", colour:"", tags:[], wearCount:0, lastWorn:nil)
        let now = Date()
        markWorn(&item, now: now)
        markWorn(&item, now: now) // second tap same instant
        XCTAssertEqual(item.wearCount, 1)
    }
}
