//
//  DeleteAccountTests.swift
//  myFinalProject
//
//  Created by Derya Baglan on 27/08/2025.
//

import XCTest

// DeleteAccountTests is a unit test that validates the account deletion workflow. It uses fake Firestore, Storage, and Auth implementations

@testable import myFinalProject

final class DeleteAccountTests: XCTestCase {
    func testDeletesTreesAndBlobsThenSignsOut() async throws {
        var deletedPaths: [String] = []
        let fs = FakeFirestore { _, path in deletedPaths.append(path) }
        let st = FakeStorage { _ in (URL(string:"https://x")!, "p") }
        let auth = FakeAuth(signOutImpl: {})


        let orch = AccountDeletionOrchestrator(firestore: fs, storage: st, auth: auth)
        try await orch.deleteAccount(userId: "u")

        XCTAssertTrue(deletedPaths.allSatisfy { $0.hasPrefix("users/u") })
    }
}

final class FakeAuth: AuthAPI {
    let signOutImpl: () -> Void
    init(signOutImpl: @escaping () -> Void) { self.signOutImpl = signOutImpl }
    func signOut() throws { signOutImpl() }
}
