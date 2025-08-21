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

/// Orchestrates a  full account deletion:
/// 1) remove profile image in Storage (if any),
/// 2) delete all wardrobe item documents (and their images),
/// 3) delete the top-level user document,
/// 4) finally delete the Firebase Auth user.
///
/// Design notes (for viva):
/// - We do Storage deletions with `try?` on purpose: failing to remove a blob should not block
///   metadata/doc cleanup; it’s better to avoid leaving live Firestore docs behind.
/// - Order is “children → parent → Auth user” to avoid dangling subcollections/doc reads after parent gone.
/// - No Firestore multi-collection transaction exists; this linear, awaited sequence keeps state consistent.
/// - We throw `reauthRequired` if `user.delete()` complains about stale credentials; the UI can prompt re-auth.

final class AccountDeletionService {
    private let db = Firestore.firestore()

    /// Deletes profile image, all wardrobe item images/docs, user doc, then the Auth user.
    func deleteCurrentUserCompletely() async throws {
        // Ensure we have a session; without it we don't know which user to delete.
        guard let user = Auth.auth().currentUser else { throw AccountDeletionError.notSignedIn }
        let uid = user.uid
        let userDoc = db.collection("users").document(uid)

        // 1) Read user doc to discover profile image path (if saved earlier during profile setup).
        //    Reading first avoids having to guess Storage paths.
        let snap = try await userDoc.getDocument()
        let profilePath = snap.data()?["profileImagePath"] as? String

        // 1a) delete the profile image blob.
        if let p = profilePath {
            try? await StorageBucket.instance.reference(withPath: p).delete()
        }

        // 2) Delete wardrobe items under the user doc:
        //    - for each item doc, try to delete its image blob first (best-effort),
        //    - then delete the Firestore document so the UI no longer surfaces the item.
        let itemsSnap = try await userDoc.collection("items").getDocuments()
        for d in itemsSnap.documents {
            if let path = d.data()["imagePath"] as? String {
                // Best-effort blob delete; don’t block the document deletion on blob errors.
                try? await StorageBucket.instance.reference(withPath: path).delete()
            }
            // Hard delete of the item document; if this fails, we bubble the error so the UI can retry.
            try await d.reference.delete()
        }

        // 3) Remove the top-level user document last (after children), so reads during step 2 still work.
        try await userDoc.delete()

        // 4) Finally, delete the Auth user record.
        //    This may throw `ERROR_REQUIRES_RECENT_LOGIN` if credentials are stale.
        do {
            try await user.delete()
        } catch {
            // Surface a specific error so the UI can trigger a re-auth flow, then retry deletion.
            throw AccountDeletionError.reauthRequired
        }
    }
}
