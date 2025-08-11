//
//  SignupFlowViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//
//
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

final class SignupFlowViewModel: ObservableObject {
    // Inputs
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var agreedToTerms: Bool = false

    // UI state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showTAndCs: Bool = false
    @Published var showSocialAlert: Bool = false
    @Published var alertMessage: String = ""

    // Navigation flags
    @Published var goToSignIn: Bool = false
    @Published var showEmailVerification: Bool = false

    var canContinue: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && agreedToTerms
    }

    // MARK: - Sign up
    func signUp() {
        errorMessage = ""

        // Basic validation (kept similar to your previous logic)
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email."
            return
        }
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
            guard let self else { return }
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                return
            }

            guard let user = result?.user else { return }

            // Seed a minimal user document (profile details are set later in ProfileSetupView)
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).setData([
                "email": self.email,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true) { _ in }

            // Send verification email and move to EmailVerificationFlowView
            user.sendEmailVerification { _ in
                DispatchQueue.main.async {
                    self.showEmailVerification = true
                }
            }
        }
    }

    // MARK: - Password helpers
    private func containsUppercase(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .uppercaseLetters) != nil
    }

    private func containsNumberOrSymbol(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .decimalDigits) != nil ||
        text.rangeOfCharacter(from: CharacterSet.symbols.union(.punctuationCharacters)) != nil
    }
}
