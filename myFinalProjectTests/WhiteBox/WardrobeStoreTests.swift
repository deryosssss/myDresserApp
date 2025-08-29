//
//  WardrobeStoreTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//

// WardrobeStoreTests is a unit test suite for the wardrobe data store. It ensures:
// Image resizing: ensureUnderLimit compresses large images under a byte limit and outputs JPEG (image/jpeg).
// Create item with image: when upload succeeds, Firestore writes include both imageURL and imagePath, plus a server timestamp.
// Failure safety: if upload fails, no partial Firestore document is written.

import XCTest
@testable import myFinalProject

final class WardrobeStoreTests: XCTestCase {

    func testEnsureUnderLimit_ResizesAndSetsJPEG() async throws {
        let big = UIImage.solid(color: .red, size: .init(width: 4000, height: 4000)).jpegData(compressionQuality: 1)!
        let (data, type) = try await WardrobeStore.ensureUnderLimit(data: big, limitBytes: 10 * 1024 * 1024)
        XCTAssertLessThan(data.count, 10 * 1024 * 1024)
        XCTAssertEqual(type, "image/jpeg")
    }

    func testCreateItemWithImage_SuccessWritesBothURLAndPath() async throws {
        let storage = FakeStorage { _ in (URL(string: "https://x/y.jpg")!, "users/u/items/i.jpg") }
        var wrote: [String:Any] = [:]
        let firestore = FakeFirestore { payload, _ in wrote = payload }

        let store = WardrobeStore(storage: storage, firestore: firestore)
        try await store.createItemWithImage(data: Data([1,2]), userId: "u")

        XCTAssertEqual(wrote["imageURL"] as? String, "https://x/y.jpg")
        XCTAssertEqual(wrote["imagePath"] as? String, "users/u/items/i.jpg")
        XCTAssertNotNil(wrote["addedAt"]) // server timestamp
    }

    func testCreateItemWithImage_UploadFails_NoPartialDoc() async throws {
        struct Err: Error {}
        let storage = FakeStorage { _ in throw Err() }
        var wrote = false
        let firestore = FakeFirestore { _, _ in wrote = true }

        let store = WardrobeStore(storage: storage, firestore: firestore)
        do {
            try await store.createItemWithImage(data: Data(), userId: "u")
            XCTFail("expected failure")
        } catch { /* ok */ }
        XCTAssertFalse(wrote)
    }
}

// MARK: - Fakes
final class FakeFirestore: FirestoreAPI {
    let setImpl: ([String:Any], String) async throws -> Void
    init(_ setImpl: @escaping ([String:Any], String) async throws -> Void) { self.setImpl = setImpl }
    func set(_ doc: [String : Any], at path: String) async throws { try await setImpl(doc, path) }
}

final class FakeStorage: StorageAPI {
    let uploadImpl: (Data) async throws -> (URL, String)
    init(_ uploadImpl: @escaping (Data) async throws -> (URL, String)) { self.uploadImpl = uploadImpl }
    func upload(data: Data, path: String, contentType: String) async throws -> (url: URL, path: String) {
        _ = (path, contentType) // inspect if you want
        return try await uploadImpl(data)
    }
}

// MARK: - Test image helper
import UIKit
private extension UIImage {
    static func solid(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}
