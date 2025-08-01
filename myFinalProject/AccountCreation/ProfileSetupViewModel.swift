//
//  ProfileSetupViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class ProfileSetupViewModel: ObservableObject {
    // User input
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var userName = ""
    @Published var dob = Date()
    @Published var genderPresentation = ""
    @Published var profileImage: UIImage? = nil

    // UI state
    @Published var showImagePicker = false
    @Published var showDatePicker = false
    @Published var showGenderPicker = false

    @Published var errorMessage = ""
    @Published var isSaving = false
    @Published var showSuccess = false
    @Published var goToShoppingHabits = false

    let genderOptions = [
        "Woman",
        "Man",
        "Non-binary",
        "Transgender",
        "Prefer not to say",
        "Other"
    ]

    var canContinue: Bool {
        !firstName.isEmpty && !userName.isEmpty && !genderPresentation.isEmpty && dob < Date()
    }

    var dobString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dob)
    }

    var isOver18: Bool {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        if let age = ageComponents.year, age >= 18 {
            return true
        }
        return false
    }

    func continueTapped() {
        errorMessage = ""
        if !isOver18 {
            errorMessage = "You must be at least 18 years old to use this app."
            return
        }
        if showSuccess {
            goToShoppingHabits = true
        } else {
            saveProfile()
        }
    }

    // MARK: - Save Data
    func saveProfile() {
        errorMessage = ""
        showSuccess = false
        isSaving = true

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not authenticated. Please sign in again."
            isSaving = false
            return
        }

        // If the user picked an image, upload it first
        if let img = profileImage, let imgData = img.jpegData(compressionQuality: 0.7) {
            let storageRef = Storage.storage().reference()
                .child("profile_images/\(user.uid).jpg")
            storageRef.putData(imgData, metadata: nil) { [weak self] metadata, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Image upload failed: \(error.localizedDescription)"
                        self.isSaving = false
                    }
                    return
                }
                // Get download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Image URL failed: \(error.localizedDescription)"
                            self.isSaving = false
                        }
                        return
                    }
                    self.saveProfileDocument(imageURL: url?.absoluteString)
                }
            }
        } else {
            // No image selected
            saveProfileDocument(imageURL: nil)
        }
    }

    func saveProfileDocument(imageURL: String?) {
        guard let user = Auth.auth().currentUser else {
            self.errorMessage = "Session expired. Please sign in again."
            self.isSaving = false
            return
        }
        let db = Firestore.firestore()
        let userDoc: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "userName": userName,
            "dob": Timestamp(date: dob),
            "genderPresentation": genderPresentation,
            "profileImageURL": imageURL ?? "",
            "email": user.email ?? "",
            "uid": user.uid,
            "createdAt": FieldValue.serverTimestamp()
        ]
        db.collection("users").document(user.uid).setData(userDoc, merge: true) { [weak self] err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSaving = false
                if let err = err {
                    self.errorMessage = "Could not save profile: \(err.localizedDescription)"
                } else {
                    self.errorMessage = ""
                    self.showSuccess = true
                    self.goToShoppingHabits = true
                }
            }
        }
    }
}
