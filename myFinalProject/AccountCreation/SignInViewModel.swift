//
//  SignInViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import FirebaseAuth
import SwiftUI

class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage = ""
    @Published var isLoading = false

    @Published var goToForgotPassword = false
    @Published var goToSignUp = false
    @Published var goToHome = false

    var canContinue: Bool {
        !email.isEmpty && !password.isEmpty
    }

    func signIn() {
        errorMessage = ""
        guard email.contains("@"), password.count >= 6 else {
            errorMessage = "Please enter a valid email and password."
            return
        }
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error as NSError? {
                    let code = AuthErrorCode(rawValue: error.code)
                    switch code {
                    case .wrongPassword, .userNotFound:
                        self.errorMessage = "Incorrect email or password."
                    case .networkError:
                        self.errorMessage = "Unable to connect. Please check your connection and try again."
                    case .userDisabled:
                        self.errorMessage = "Account disabled. Please contact support."
                    case .tooManyRequests:
                        self.errorMessage = "Account temporarily locked. Try again later or reset your password."
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    // Success: Redirect to home/dashboard
                    self.goToHome = true
                }
            }
        }
    }

    func goForgotPassword() { goToForgotPassword = true }
    func goSignUp() { goToSignUp = true }
}
