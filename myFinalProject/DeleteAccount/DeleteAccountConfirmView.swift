//
//  DeleteAccountConfirmView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// screen shown before account deletion just to make sure the account is deleted with confirmation.
// If confirmation is given the account is deleted immediately afterwards 

struct DeleteAccountConfirmView: View {
    @State private var confirmChecked = false
    @State private var showDeletedScreen = false
    @State private var goToHome = false
    @State private var errorMessage = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer().frame(height: 200)

                    Text("This action is irreversible. You will lose all photos, usage stats, outfits, and AI suggestions.")
                        .font(AppFont.agdasima(size: 24))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)

                    HStack {
                        Button(action: { confirmChecked.toggle() }) {
                            Image(systemName: confirmChecked ? "checkmark.square" : "square")
                                .foregroundColor(.black)
                                .font(.system(size: 22))
                        }
                        Text("I understand I cannot recover my account")
                            .font(AppFont.agdasima(size: 18))
                            .foregroundColor(.black)
                    }
                    .padding(.top, 140)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    HStack {
                        Button(action: { goToHome = true }) {
                            Text("Cancel")
                                .font(AppFont.agdasima(size: 20))
                                .foregroundColor(.black)
                        }
                        .aid("settings.cancelDelete")

                        Spacer()

                        Button(action: { startDeletion() }) {
                            HStack(spacing: 8) {
                                if isWorking { ProgressView().scaleEffect(0.9) }
                                Text(isWorking ? "Deleting…" : "Delete My Account")
                                    .font(AppFont.agdasima(size: 20))
                            }
                            .foregroundColor(.red)
                        }
                        .aid("settings.confirmDelete")
                        .disabled(!confirmChecked || isWorking)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 200)
                }
                .navigationDestination(isPresented: $showDeletedScreen) {
                    AccountDeletedView()
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $goToHome) {
                    RootView()
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    // MARK: - Deletion Orchestrator
    private func startDeletion() {
        errorMessage = ""
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You are not signed in."
            return
        }

        isWorking = true
        let uid = user.uid

        Task {
            do {
                try await deleteFirestoreData(uid: uid)
                try await deleteStorageData(uid: uid)
                try await user.delete()

                await MainActor.run {
                    isWorking = false
                    showDeletedScreen = true
                }
            } catch {
                if let err = error as NSError?,
                   err.domain == AuthErrorDomain,
                   err.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    await MainActor.run {
                        isWorking = false
                        errorMessage = "Please re-authenticate (log out and in again) and then try deleting your account."
                    }
                } else {
                    await MainActor.run {
                        isWorking = false
                        errorMessage = "Failed to delete account: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // MARK: - Firestore Cleanup
    private func deleteFirestoreData(uid: String) async throws {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(uid)

        let itemsSnap = try await userDoc.collection("items").getDocuments()
        if !itemsSnap.documents.isEmpty {
            let batch = db.batch()
            for d in itemsSnap.documents { batch.deleteDocument(d.reference) }
            try await batch.commit()
        }

        let legacySnap = try await db.collection("wardrobeItems")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        if !legacySnap.documents.isEmpty {
            let batch = db.batch()
            for d in legacySnap.documents { batch.deleteDocument(d.reference) }
            try await batch.commit()
        }

        try await userDoc.delete()
    }

    // MARK: - Storage Cleanup
    private func deleteStorageData(uid: String) async throws {
        let storage = Storage.storage()
        try await deleteAllFiles(in: storage.reference(withPath: "profile_images/\(uid)"))
        try await deleteAllFiles(in: storage.reference(withPath: "wardrobe_images/\(uid)"))
    }

    private func deleteAllFiles(in folder: StorageReference) async throws {
        let list = try await folder.listAll()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for item in list.items { group.addTask { try await item.delete() } }
            for try await _ in group {}
        }
        for prefix in list.prefixes { try await deleteAllFiles(in: prefix) }
    }
}




