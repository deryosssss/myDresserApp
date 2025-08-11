//
//  ProfileViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    // Display data
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var joinDate: String = ""
    @Published var profileImage: UIImage? = nil

    // Loading / actions
    @Published var isLoading: Bool = true
    @Published var isWorking: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // Delete flow
    @Published var showDeleteConfirm: Bool = false
    @Published var showReauthSheet: Bool = false
    @Published var reauthEmail: String = ""
    @Published var reauthPassword: String = ""

    private var listener: ListenerRegistration?

    init() {
        fetchUserData()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Fetch user profile
    func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        self.email = user.email ?? ""

        let db = Firestore.firestore()
        let ref = db.collection("users").document(user.uid)

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            // Hop back to the main actor for all @Published mutations
            Task { @MainActor in
                self.isLoading = false
                guard error == nil, let data = snapshot?.data() else { return }

                self.username = (data["userName"] as? String) ?? self.username

                if let ts = data["createdAt"] as? Timestamp {
                    let date = ts.dateValue()
                    let fmt = DateFormatter()
                    fmt.dateStyle = .medium
                    self.joinDate = fmt.string(from: date)
                }

                if let imageURL = data["profileImageURL"] as? String, !imageURL.isEmpty {
                    await self.fetchProfileImage(from: imageURL)
                } else {
                    self.profileImage = nil
                }
            }
        }
    }

    private func fetchProfileImage(from urlString: String) async {
        // Works with https download URLs; if it fails, fall back gracefully.
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                self.profileImage = img
            }
        } catch {
            // Optional: ignore or surface error
        }
    }

    // MARK: - Sign out
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            presentError("Failed to sign out: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete account
    func requestDeleteAccount() {
        showDeleteConfirm = true
    }

    func confirmDeleteAccount() {
        showDeleteConfirm = false
        deleteAccount()
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            presentError("No authenticated user.")
            return
        }
        let uid = user.uid

        isWorking = true
        Task {
            do {
                try await deleteFirestoreData(uid: uid)
                try await deleteStorageData(uid: uid)
                try await user.delete() // may throw requiresRecentLogin
                self.isWorking = false
            } catch {
                self.isWorking = false
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

    // Re-auth then retry delete
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
            self.deleteAccount()
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

        // 2) (Optional) Delete legacy top-level wardrobeItems owned by this uid
        let legacySnap = try await db.collection("wardrobeItems")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        if !legacySnap.documents.isEmpty {
            let batch = db.batch()
            for d in legacySnap.documents { batch.deleteDocument(d.reference) }
            try await batch.commit()
        }

        // 3) Delete the user doc last (subcollections aren't auto-deleted)
        try await userDoc.delete()
    }

    private func deleteStorageData(uid: String) async throws {
        let storage = StorageBucket.instance
        try await deleteAllFiles(in: storage.reference(withPath: "profile_images/\(uid)"))
        try await deleteAllFiles(in: storage.reference(withPath: "wardrobe_images/\(uid)"))
    }

    private func deleteAllFiles(in folder: StorageReference) async throws {
        let list = try await folder.listAll()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for item in list.items {
                group.addTask { try await item.delete() }
            }
            for try await _ in group {}
        }
        for prefix in list.prefixes {
            try await deleteAllFiles(in: prefix)
        }
    }

    // MARK: - Errors
    private func presentError(_ message: String) {
        self.errorMessage = message
        self.showError = true
    }
}
