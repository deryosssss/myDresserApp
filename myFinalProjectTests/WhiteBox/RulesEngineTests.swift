//
//  RulesEngineTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//

import XCTest
@testable import myFinalProject

// RulesEngineTests is a unit test suite for the outfit recommendation rules engine. It verifies that:
// Category constraints are respected — a suggested outfit always includes top, bottom, and footwear.
// Weather bias works — if it’s raining and outerwear is available, it gets added.
// Locks keep chosen items fixed, while other layers vary between suggestions.
                            
final class RulesEngineTests: XCTestCase {

    func testCategoryConstraints() {
        let inv = Inventory(top:["t1"], bottom:["b1"], footwear:["f1"], outerwear:[])
        let outfit = RulesEngine.suggest(inventory: inv, weather: .clear, rng: SeededRNG(seed: 42))
        XCTAssertNotNil(outfit.top)
        XCTAssertNotNil(outfit.bottom)
        XCTAssertNotNil(outfit.footwear)
    }

    func testWeatherRainAddsOuterwearWhenAvailable() {
        let inv = Inventory(top:["t1"], bottom:["b1"], footwear:["f1"], outerwear:["o1"])
        let outfit = RulesEngine.suggest(inventory: inv, weather: .rain, rng: SeededRNG(seed: 1))
        XCTAssertEqual(outfit.outerwear, "o1")
    }

    func testLocksUnchangedOthersVary() {
        let inv = Inventory(top:["t1","t2"], bottom:["b1","b2"], footwear:["f1","f2"], outerwear:[])
        let locks = Locks(top:"t1", bottom:nil, footwear:nil, outerwear:nil)
        let a = RulesEngine.suggest(inventory: inv, weather: .clear, locks: locks, rng: SeededRNG(seed: 1))
        let b = RulesEngine.suggest(inventory: inv, weather: .clear, locks: locks, rng: SeededRNG(seed: 2))
        XCTAssertEqual(a.top, "t1") // locked
        XCTAssertNotEqual(a.bottom, b.bottom) // varied
    }
}

// MARK: - Seeded RNG to make tests deterministic (drop in your app too if useful)
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x12345678 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
