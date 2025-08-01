//
//  EmailVerificationViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//
import Foundation
import FirebaseAuth

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
