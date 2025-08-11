//
//  AccountDeletionService.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

enum AccountDeletionError: Error { case notSignedIn, reauthRequired }

final class AccountDeletionService {
    private let db = Firestore.firestore()

    /// Deletes profile image, all wardrobe item images/docs, user doc, then the Auth user.
    func deleteCurrentUserCompletely() async throws {
        guard let user = Auth.auth().currentUser else { throw AccountDeletionError.notSignedIn }
        let uid = user.uid
        let userDoc = db.collection("users").document(uid)

        // 1) Fetch user doc to get profile image path
        let snap = try await userDoc.getDocument()
        let profilePath = snap.data()?["profileImagePath"] as? String
        if let p = profilePath { try? await StorageBucket.instance.reference(withPath: p).delete() }

        // 2) Delete wardrobe items (docs + images)
        let itemsSnap = try await userDoc.collection("items").getDocuments()
        for d in itemsSnap.documents {
            if let path = d.data()["imagePath"] as? String {
                try? await StorageBucket.instance.reference(withPath: path).delete()
            }
            try await d.reference.delete()
        }

        // 3) Delete user doc
        try await userDoc.delete()

        // 4) Delete the auth user (may require recent login)
        do {
            try await user.delete()
        } catch {
            // Firebase may require re-auth if the session is old
            throw AccountDeletionError.reauthRequired
        }
    }
}
