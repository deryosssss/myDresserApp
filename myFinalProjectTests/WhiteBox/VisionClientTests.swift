//
//  VisionClientTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//
import XCTest
@testable import myFinalProject

final class VisionClientTests: XCTestCase {
    func testAddsApiKeyAndBacksOffOn429() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        var seenHeaders: [String:String] = [:]
        var called = 0

        MockURLProtocol.handler = { req in
            called += 1
            seenHeaders = req.allHTTPHeaderFields ?? [:]
            // First attempt: 429, then 200
            if called == 1 {
                return (HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data())
            } else {
                let ok = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (ok, Data(#"{"labels":["shirt"]}"#.utf8))
            }
        }

        // REQUIRES: your client init accepts injected URLSession
        let client = VisionClient(session: session, apiKey: "abc123")
        let _ = try await client.detect(ImageStub.data)

        XCTAssertEqual(seenHeaders["Authorization"], "Bearer abc123")
        XCTAssertGreaterThanOrEqual(called, 2) // retried after 429
    }
}

enum ImageStub {
    static let data = Data(repeating: 0, count: 4)
}
