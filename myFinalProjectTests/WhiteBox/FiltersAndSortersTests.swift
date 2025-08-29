//
//  FiltersAndSortersTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//
// FiltersAndSortersTests is a unit test suite for wardrobe item filtering and sorting. It checks that:
// Filtering: items match when search text, tags, and colour filters intersect correctly, with normalization (e.g., trimming and case-insensitive checks). Non-matching text/colour returns false.
// Sorting: items with the same name fall back to creation date for stable ordering (older first in this test).

import XCTest
@testable import myFinalProject

final class FiltersAndSortersTests: XCTestCase {

    func testMatchesFilters_IntersectionAndNormalization() {
        let vm = WardrobeViewModel()
        let item = WardrobeItem(id: "1", name: " Blue  Shirt ", colour: "Navy", tags: ["smart", "summer"])

        // REQUIRES: real signature; change as needed
        XCTAssertTrue(vm.matchesFilters(item: item,
                                        text: "blue",
                                        tags: ["smart","gym"], // intersection => true
                                        colour: "navy"))
        XCTAssertFalse(vm.matchesFilters(item: item,
                                         text: "green",
                                         tags: ["gym"],
                                         colour: "olive"))
    }

    func testSorters_StableOrderingAndFallbacks() {
        var items = [
            WardrobeItem(id:"1", name:"Alpha", colour:"Blue", tags:[], addedAt: Date(timeIntervalSince1970: 20)),
            WardrobeItem(id:"2", name:"Alpha", colour:"Blue", tags:[], addedAt: Date(timeIntervalSince1970: 10))
        ]
        // REQUIRES: your sorter
        items.sort(using: ItemSort.byNameAZThenDateFallback)
        XCTAssertEqual(items.map(\.id), ["2","1"]) // older first for equal name
    }
}
