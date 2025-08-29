//
//  VisionMapperTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//

import XCTest
@testable import myFinalProject

// Item detection: known labels (e.g., “shirt”, “blue”) are recognized, while unknown ones fall into customTags.
// Deep tagging: even if responses are partial or malformed (e.g., tags: null), mapping is safe and returns empty arrays rather than crashing.

final class VisionMapperTests: XCTestCase {

    func testItemDetection_HappyPath() throws {
        let json = #"{"labels": ["shirt","blue","unknown_foo"]}"#
        let data = Data(json.utf8)
        let resp = try JSONDecoder().decode(ItemDetectionResponse.self, from: data)
        let mapped = TagMapper.toModel(resp)
        XCTAssertTrue(mapped.known.contains("shirt"))
        XCTAssertTrue(mapped.customTags.contains("unknown_foo"))
    }

    func testDeepTagging_PartialAndMalformedAreSafe() throws {
        let json = #"{"tags": null}"# // partial
        let data = Data(json.utf8)
        let resp = try JSONDecoder().decode(DeepTaggingResponse.self, from: data)
        let mapped = TagMapper.toModel(resp)
        XCTAssertNotNil(mapped) // design choice: returns empty arrays
        XCTAssertTrue(mapped.known.isEmpty)
        XCTAssertTrue(mapped.customTags.isEmpty)
    }
}
