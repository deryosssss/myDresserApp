//
//  ProfileSetupViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage

/// ViewModel for the first-time profile setup flow.
/// Responsibilities:
/// • Owns the user’s input (names, DOB, gender, optional avatar).
/// • Validates (incl. 18+ check).
/// • Optionally uploads the avatar to Cloud Storage (gets a public URL).
/// • Saves/merges the profile document in Firestore under `users/{uid}`.
/// • Exposes UI state flags to drive navigation and loading indicators.
@MainActor
final class ProfileSetupViewModel: ObservableObject {

    // MARK: - User input (bound to the form fields)

    /// Required first name (trimmed before save).
    @Published var firstName = ""

    /// Optional last name (trimmed before save).
    @Published var lastName = ""

    /// Required username/handle (trimmed before save).
    @Published var userName = ""

    /// Date of birth; defaults to `Date()` so UI shows a placeholder until user picks.
    @Published var dob = Date()

    /// Chosen gender presentation (from a constrained list for clean analytics).
    @Published var genderPresentation = ""

    /// Optional avatar image selected by the user (raw UIImage before upload).
    @Published var profileImage: UIImage? = nil


    // MARK: - UI state (drives sheets, spinners, nav)

    /// Controls the photo picker sheet (UIKit bridge).
    @Published var showImagePicker = false

    /// Controls the DOB wheel picker sheet.
    @Published var showDatePicker = false

    /// Controls the gender action sheet.
    @Published var showGenderPicker = false

    /// Inline error text for validation or save failures.
    @Published var errorMessage = ""

    /// When true, disables inputs and shows a spinner on the CTA.
    @Published var isSaving = false

    /// One-shot “saved!” feedback so the user knows work completed.
    @Published var showSuccess = false

    /// Navigation trigger → ShoppingHabitsView (used by `.navigationDestination`).
    @Published var goToShoppingHabits = false


    /// Backing list for the gender action sheet. Keep values human-readable.
    let genderOptions = ["Woman","Man","Non-binary","Transgender","Prefer not to say","Other"]


    // MARK: - Derived UI flags/strings

    /// Gate for enabling the Continue button; also used to dim the button when incomplete.
    var canContinue: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !genderPresentation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        dob < Date() // sanity: DOB must be in the past
    }

    /// Pretty DOB label for the button (localized by DateFormatter).
    var dobString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: dob)
    }

    /// Simple age check used before saving; keeps business rule close to where it's used.
    private var isOver18: Bool {
        (Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0) >= 18
    }


    // MARK: - User actions

    /// Primary CTA from the view.
    /// Flow:
    /// 1) Validate age (UI-level business rule).
    /// 2) If we already saved (showSuccess), move forward immediately.
    /// 3) Else, run the save pipeline (image upload → Firestore merge).
    func continueTapped() {
        errorMessage = ""
        guard isOver18 else {
            errorMessage = "You must be at least 18 years old to use this app."
            return
        }
        if showSuccess {
            // Already saved previously; allow the user to proceed without re-uploading.
            goToShoppingHabits = true
        } else {
            saveProfile()
        }
    }


    // MARK: - Save pipeline

    /// Orchestrates the save:
    /// 1) Ensure Firebase Auth user exists (hard requirement for paths/ownership).
    /// 2) If avatar provided, upload it to Storage and fetch a download URL.
    /// 3) Compose Firestore document (merge to allow incremental onboarding).
    func saveProfile() {
        errorMessage = ""
        showSuccess = false
        isSaving = true

        guard let user = Auth.auth().currentUser else {
            // If we lost session, stop immediately and prompt re-auth.
            errorMessage = "Not authenticated. Please sign in again."
            isSaving = false
            return
        }

        // Optional image upload branch. If absent, skip straight to Firestore write.
        if let img = profileImage {
            uploadProfileImage(img, for: user) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let uploaded):
                    // Pass the public URL + storage path to Firestore for future retrieval/cleanup.
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


    // MARK: - Storage (avatar)

    /// Simple container for uploaded image metadata (public URL + Storage path).
    private struct Uploaded { let url: String; let path: String }

    /// Compresses and uploads the avatar to Cloud Storage, then returns the download URL.
    /// Why compress:
    /// • Reduces bandwidth and Storage cost.
    /// • Keeps uploads snappy on mobile networks.
    ///
    /// Notes:
    /// • Uses a centralized `StorageBucket.instance` wrapper to obtain a bucket reference.
    ///   If you don’t have this helper, replace with:
    ///     `let ref = Storage.storage().reference(withPath: path)`
    private func uploadProfileImage(
        _ image: UIImage,
        for user: User,
        completion: @escaping (Result<Uploaded?, Error>) -> Void
    ) {
        // Downscale very large images to a reasonable pixel budget (longest side = 1080px).
        let resized = imageByScaling(image, maxDimension: 1080)

        // Baseline JPEG quality; then, if still too big, step down quality.
        guard var data = resized.jpegData(compressionQuality: 0.85) else {
            // If export fails, proceed without an avatar (non-blocking UX).
            completion(.success(nil))
            return
        }

        // Hard cap ~10MB to avoid huge uploads and Storage bloat.
        let tenMB = 10 * 1024 * 1024
        var q: CGFloat = 0.8
        while data.count > tenMB, q > 0.3 {
            q -= 0.1
            if let d = resized.jpegData(compressionQuality: q) {
                data = d
            } else {
                break
            }
        }

        // Stable path so subsequent uploads overwrite the previous avatar.
        let path = "profile_images/\(user.uid)/profile.jpg"

        // App-level bucket helper; see note above if you prefer `Storage.storage()`.
        let ref = StorageBucket.instance.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        // Start upload; this callback comes on a background thread, but we're already @MainActor
        // at the VM boundary, so we just marshal the result via `completion`.
        ref.putData(data, metadata: meta) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            // After upload, fetch a publicly accessible (tokenized) URL for rendering later.
            ref.downloadURL { url, err in
                if let err = err {
                    completion(.failure(err))
                } else if let url = url {
                    completion(.success(Uploaded(url: url.absoluteString, path: path)))
                } else {
                    // Edge case: uploaded, but no URL (treat as “no avatar”).
                    completion(.success(nil))
                }
            }
        }
    }


    // MARK: - Firestore (profile document)

    /// Writes/merges the profile into `users/{uid}` with server timestamps.
    /// Why merge:
    /// • Allows partial onboarding steps and later edits without clobbering other fields.
    private func saveProfileDocument(imageURL: String?, imagePath: String?) {
        guard let user = Auth.auth().currentUser else {
            self.errorMessage = "Session expired. Please sign in again."
            self.isSaving = false
            return
        }

        let db = Firestore.firestore()

        // Prepare clean, trimmed values; keep server authority for createdAt.
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

        // Merge to avoid overwriting other user fields written by different flows.
        db.collection("users").document(user.uid).setData(doc, merge: true) { [weak self] err in
            guard let self = self else { return }
            self.isSaving = false
            if let err = err {
                self.errorMessage = "Could not save profile: \(err.localizedDescription)"
            } else {
                self.errorMessage = ""
                self.showSuccess = true
                self.goToShoppingHabits = true // Triggers navigation in the view.
            }
        }
    }
}


// MARK: - Image utilities

/// Scales `image` so its longest side equals `maxDimension` (maintaining aspect ratio).
/// Uses `scale = 1.0` to keep predictable pixel density; quality is handled by JPEG compression later.
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
