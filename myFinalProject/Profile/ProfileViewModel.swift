//
//  ProfileViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025
//
//  1) On init, reads Auth user + subscribes to Firestore /users/{uid} for live profile updates.
//  2) Keeps UI fields (username, email, join date, avatar) in sync; downloads avatar if URL present.
//  3) Exposes sign-out, and full delete flow with re-auth fallback (if required by Firebase).
//  4) On delete, removes user data from Firestore & Storage, then deletes the Auth user.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    // Display data bound to the Profile screen
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var joinDate: String = ""
    @Published var profileImage: UIImage? = nil

    // Loading / action flags for spinners & buttons
    @Published var isLoading: Bool = true
    @Published var isWorking: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // Delete flow UI state (confirm dialog + re-auth sheet)
    @Published var showDeleteConfirm: Bool = false
    @Published var showReauthSheet: Bool = false
    @Published var reauthEmail: String = ""
    @Published var reauthPassword: String = ""

    private var listener: ListenerRegistration? // Firestore snapshot listener token

    init() {
        fetchUserData() // kick off initial fetch + Firestore subscription
    }

    deinit {
        listener?.remove() // stop listening when VM is deallocated
    }

    // MARK: - Fetch user profile
    func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false // no user → stop spinner and bail
            return
        }
        self.email = user.email ?? "" // show email from Auth

        // Join date from Auth user metadata
        if let created = user.metadata.creationDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            self.joinDate = fmt.string(from: created)
        }

        // Listen to Firestore user doc for live username/avatar changes
        let db = Firestore.firestore()
        let ref = db.collection("users").document(user.uid)

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isLoading = false // first response → hide loading
                guard error == nil, let data = snapshot?.data() else { return }

                // Prefer modern "username" key; fall back to legacy "userName"
                if let u = (data["username"] as? String) ?? (data["userName"] as? String) {
                    self.username = u
                }

                // Accept both photoURL and profileImageURL; empty → clear image
                if let urlString = (data["photoURL"] as? String)
                    ?? (data["profileImageURL"] as? String),
                   !urlString.isEmpty {
                    await self.fetchProfileImage(from: urlString)
                } else {
                    self.profileImage = nil
                }
            }
        }
    }

    private func fetchProfileImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return } // validate URL
        do {
            let (data, _) = try await URLSession.shared.data(from: url) // download bytes
            if let img = UIImage(data: data) {
                self.profileImage = img // update avatar on success
            }
        } catch {
            // ignore download errors silently to avoid noisy UI
        }
    }

    // MARK: - Sign out
    func signOut() {
        do {
            try Auth.auth().signOut() // clear Firebase session
        } catch {
            presentError("Failed to sign out: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete account
    func requestDeleteAccount() { showDeleteConfirm = true } // open confirm dialog

    func confirmDeleteAccount() {
        showDeleteConfirm = false // close confirm
        deleteAccount()           // proceed with deletion
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            presentError("No authenticated user.") // defensive guard
            return
        }
        let uid = user.uid

        isWorking = true // show spinner while deleting
        Task {
            do {
                try await deleteFirestoreData(uid: uid) // purge Firestore docs
                try await deleteStorageData(uid: uid)   // purge Storage files
                try await user.delete()                 // delete Auth account (may require re-login)
                self.isWorking = false
            } catch {
                self.isWorking = false
                // If Firebase requires recent login, prompt re-auth; otherwise show error
                if let nserr = error as NSError?,
                   nserr.domain == AuthErrorDomain,
                   nserr.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    self.reauthEmail = self.email
                    self.reauthPassword = ""
                    self.showReauthSheet = true
                } else {
                    presentError("Delete failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // Re-authenticate, then retry the delete flow
    func performReauthAndDelete() {
        guard let user = Auth.auth().currentUser else { return }
        let cred = EmailAuthProvider.credential(withEmail: reauthEmail, password: reauthPassword)
        isWorking = true
        user.reauthenticate(with: cred) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                self.isWorking = false
                self.presentError("Re-authentication failed: \(error.localizedDescription)")
                return
            }
            self.showReauthSheet = false
            self.deleteAccount() // now retry deletion with fresh credentials
        }
    }

    // MARK: - Firestore / Storage cleanup
    private func deleteFirestoreData(uid: String) async throws {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(uid)

        // 1) Delete nested items under users/{uid}/items
        let itemsSnap = try await userDoc.collection("items").getDocuments()
        if !itemsSnap.documents.isEmpty {
            let batch = db.batch()
            for d in itemsSnap.documents { batch.deleteDocument(d.reference) }
            try await batch.commit()
        }

        // 2) Delete legacy collection docs scoped by userId (if that schema existed)
        let legacySnap = try await db.collection("wardrobeItems")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        if !legacySnap.documents.isEmpty {
            let batch = db.batch()
            for d in legacySnap.documents { batch.deleteDocument(d.reference) }
            try await batch.commit()
        }

        // 3) Delete the primary user doc last
        try await userDoc.delete()
    }

    private func deleteStorageData(uid: String) async throws {
        let storage = StorageBucket.instance
        try await deleteAllFiles(in: storage.reference(withPath: "profile_images/\(uid)"))  // user profile images
        try await deleteAllFiles(in: storage.reference(withPath: "wardrobe_images/\(uid)")) // user wardrobe images
        try await deleteAllFiles(in: storage.reference(withPath: "avatars"))                // NOTE: this targets entire folder; ensure pathing is correct per-user
    }

    private func deleteAllFiles(in folder: StorageReference) async throws {
        let list = try await folder.listAll()                        // list files + subfolders
        try await withThrowingTaskGroup(of: Void.self) { group in    // delete files concurrently
            for item in list.items {
                group.addTask { try await item.delete() }
            }
            for try await _ in group {}                              // wait for deletes
        }
        for prefix in list.prefixes {                                // recurse into subfolders
            try await deleteAllFiles(in: prefix)
        }
    }

    // MARK: - Errors
    private func presentError(_ message: String) {
        self.errorMessage = message // set error text
        self.showError = true       // toggle alert/sheet
    }
}
