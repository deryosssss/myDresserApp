//
//  EmailVerificationViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

// resendEmail() → Sends a fresh verification link and shows a success/error message.
// confirmedEmail() → Reloads the Firebase user to check verification status; if verified, sets goToProfileSetup = true to trigger navigation.
// Works hand-in-hand with EmailVerificationView to display feedback and handle user actions.
                                                                                
import Foundation
import FirebaseAuth

/// ViewModel that manages the email verification process.
/// Handles resending the verification email and checking if the user has verified.

class EmailVerificationViewModel: ObservableObject {
    let email: String
    @Published var message: String = ""
    @Published var isLoading: Bool = false
    @Published var goToProfileSetup: Bool = false

    init(email: String) {
        self.email = email
    }

    func resendEmail() {
        message = ""
        isLoading = true
        Auth.auth().currentUser?.sendEmailVerification { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.message = error.localizedDescription
                } else {
                    self?.message = "Verification email sent!"
                }
            }
        }
    }

    func confirmedEmail() {
        message = ""
        isLoading = true
        Auth.auth().currentUser?.reload { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.message = error.localizedDescription
                } else if let user = Auth.auth().currentUser, user.isEmailVerified {
                    self?.goToProfileSetup = true
                } else {
                    self?.message = "Your email is not verified yet. Please check your inbox or try again."
                }
            }
        }
    }
}
