//
//  ProfileSetupViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//
//
import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage

/// ViewModel for the first-time profile setup flow:
/// collects user input, uploads an optional profile photo to Storage,
/// writes the profile document to Firestore, and drives navigation.

@MainActor
final class ProfileSetupViewModel: ObservableObject {
    // MARK: - User input
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var userName = ""
    @Published var dob = Date()
    @Published var genderPresentation = ""
    @Published var profileImage: UIImage? = nil

    // MARK: - UI state
    @Published var showImagePicker = false
    @Published var showDatePicker = false
    @Published var showGenderPicker = false

    @Published var errorMessage = ""
    @Published var isSaving = false
    @Published var showSuccess = false
    @Published var goToShoppingHabits = false

    let genderOptions = ["Woman","Man","Non-binary","Transgender","Prefer not to say","Other"]

    var canContinue: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !genderPresentation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        dob < Date()
    }

    var dobString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: dob)
    }

    private var isOver18: Bool {
        (Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0) >= 18
    }

    func continueTapped() {
        errorMessage = ""
        guard isOver18 else { errorMessage = "You must be at least 18 years old to use this app."; return }
        if showSuccess { goToShoppingHabits = true } else { saveProfile() }
    }

    // MARK: - Save flow
    /// Orchestrates the whole save:
    /// 1) ensure user is signed in
    /// 2) (optional) upload profile image to Storage
    /// 3) write profile document to Firestore
    func saveProfile() {
        errorMessage = ""; showSuccess = false; isSaving = true

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not authenticated. Please sign in again."
            isSaving = false; return
        }

        if let img = profileImage {
            uploadProfileImage(img, for: user) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let uploaded):
                    self.saveProfileDocument(imageURL: uploaded?.url, imagePath: uploaded?.path)
                case .failure(let err):
                    self.errorMessage = "Image upload failed: \(err.localizedDescription)"
                    self.isSaving = false
                }
            }
        } else {
            saveProfileDocument(imageURL: nil, imagePath: nil)
        }
    }

    // MARK: - Storage
    /// Simple container for uploaded image metadata.
    private struct Uploaded { let url: String; let path: String }
    
    /// Compresses and uploads the profile image to Cloud Storage, then fetches a download URL.
    /// - Uses a centralized `StorageBucket.instance` (your wrapper) to get the Storage reference.
    private func uploadProfileImage(
        _ image: UIImage,
        for user: User,
        completion: @escaping (Result<Uploaded?, Error>) -> Void
    ) {
        let resized = imageByScaling(image, maxDimension: 1080)
        guard var data = resized.jpegData(compressionQuality: 0.85) else {
            completion(.success(nil)); return
        }
        let tenMB = 10 * 1024 * 1024
        var q: CGFloat = 0.8
        while data.count > tenMB, q > 0.3 {
            q -= 0.1
            if let d = resized.jpegData(compressionQuality: q) { data = d } else { break }
        }

        let path = "profile_images/\(user.uid)/profile.jpg"        // matches Storage rules
        let ref = StorageBucket.instance.reference(withPath: path) // <-- centralized bucket

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        ref.putData(data, metadata: meta) { _, error in
            if let error = error { completion(.failure(error)); return }
            ref.downloadURL { url, err in
                if let err = err { completion(.failure(err)) }
                else if let url = url { completion(.success(Uploaded(url: url.absoluteString, path: path))) }
                else { completion(.success(nil)) }
            }
        }
    }

    // MARK: - Firestore
    /// Writes/merges the profile document into `users/{uid}` with server timestamps.
    private func saveProfileDocument(imageURL: String?, imagePath: String?) {
        guard let user = Auth.auth().currentUser else {
            self.errorMessage = "Session expired. Please sign in again."
            self.isSaving = false; return
        }

        let db = Firestore.firestore()
        var doc: [String: Any] = [
            "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            "userName": userName.trimmingCharacters(in: .whitespacesAndNewlines),
            "dob": Timestamp(date: dob),
            "genderPresentation": genderPresentation,
            "email": user.email ?? "",
            "uid": user.uid,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let imageURL  { doc["profileImageURL"]  = imageURL  }
        if let imagePath { doc["profileImagePath"] = imagePath }

        db.collection("users").document(user.uid).setData(doc, merge: true) { [weak self] err in
            guard let self = self else { return }
            self.isSaving = false
            if let err = err { self.errorMessage = "Could not save profile: \(err.localizedDescription)" }
            else { self.errorMessage = ""; self.showSuccess = true; self.goToShoppingHabits = true }
        }
    }
}

// MARK: - Image utilities
/// Returns a version of `image` scaled so its longest side is `maxDimension` (or smaller),
/// preserving aspect ratio. Uses a 1.0 scale (points = pixels) since we control export quality later.
///

private func imageByScaling(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    let maxSide = max(size.width, size.height)
    guard maxSide > maxDimension else { return image }
    let scale = maxDimension / maxSide
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let img = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    return img
}
