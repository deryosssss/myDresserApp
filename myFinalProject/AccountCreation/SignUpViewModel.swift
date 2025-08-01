//
//  SignUpViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import FirebaseAuth
import SwiftUI

class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var agreedToTerms = false
    @Published var errorMessage = ""
    @Published var isLoading = false
    @Published var goToSignIn = false
    @Published var showEmailVerification = false
    @Published var showTAndCs = false
    @Published var showSocialAlert = false
    @Published var alertMessage = ""

    var canContinue: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && agreedToTerms
    }

    func signUp() {
        errorMessage = ""
        // Email check
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email."
            return
        }

        // Password strength check
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }
        guard containsUppercase(password) else {
            errorMessage = "Password must contain at least one uppercase letter."
            return
        }
        guard containsNumberOrSymbol(password) else {
            errorMessage = "Password must contain at least one number or symbol."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else if let user = result?.user {
                    user.sendEmailVerification { err in
                        if let err = err {
                            self.errorMessage = "Failed to send verification email: \(err.localizedDescription)"
                        } else {
                            self.showEmailVerification = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Password Validation Helpers

    func containsUppercase(_ text: String) -> Bool {
        let uppercase = CharacterSet.uppercaseLetters
        return text.unicodeScalars.contains(where: { uppercase.contains($0) })
    }

    func containsNumberOrSymbol(_ text: String) -> Bool {
        let numbers = CharacterSet.decimalDigits
        let symbols = CharacterSet.punctuationCharacters.union(.symbols)
        return text.unicodeScalars.contains(where: { numbers.contains($0) || symbols.contains($0) })
    }
}
