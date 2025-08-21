//
//  SignupFlowViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// MVVM ViewModel that drives the email/password sign-up flow.
/// Responsibilities:
/// - Hold form state (email/password/terms).
/// - Validate locally before hitting the network (fast feedback).
/// - Create the Firebase Auth user.
/// - Seed a minimal user doc in Firestore (profile is completed later).
/// - Send verification email and flip a navigation flag the View observes.
final class SignupFlowViewModel: ObservableObject {

    // MARK: - Form inputs (bound to TextFields / toggles)
    @Published var email: String = ""             // user’s email entry
    @Published var password: String = ""          // primary password entry
    @Published var confirmPassword: String = ""   // repeat password for mismatch check
    @Published var agreedToTerms: Bool = false    // “I agree” toggle

    // MARK: - UI state (for spinners, errors, modals)
    @Published var isLoading: Bool = false        // disables buttons & shows progress
    @Published var errorMessage: String = ""      // single-line error under form
    @Published var showTAndCs: Bool = false       // shows Terms sheet
    @Published var showSocialAlert: Bool = false  // example: for non-implemented providers
    @Published var alertMessage: String = ""      // text inside the generic alert

    // MARK: - Navigation flags (the View binds to these)
    @Published var goToSignIn: Bool = false           // route back to Sign In (optional)
    @Published var showEmailVerification: Bool = false// push EmailVerification screen

    // MARK: - Derived state
    /// Button enabled only when the user has filled all fields and accepted the terms.
    /// (We still enforce format/strength in `signUp()`.)
    var canContinue: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && agreedToTerms
    }

    // MARK: - Sign up
    /// Validates inputs, creates a Firebase user, seeds Firestore, and kicks off email verification.
    /// Flow:
    /// 1) Clear stale error.
    /// 2) Lightweight client-side validation (email, strength, match).
    /// 3) Flip loading, call `Auth.createUser`.
    /// 4) On callback: stop loading on main thread, handle error or proceed.
    /// 5) Seed minimal Firestore doc (so the account exists server-side).
    /// 6) Send verification email and flip navigation flag.
    func signUp() {
        errorMessage = "" // 1) reset

        // 2) quick client-side checks for fast UX (server will re-validate)
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

        // 3) network call
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async { self.isLoading = false } // ensure UI updates on main

            // 4) error path — surface Firebase’s message (or map to friendlier text)
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                return
            }

            // 5) seed Firestore with a minimal doc (profile is completed in the next flow)
            guard let user = result?.user else { return }
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).setData([
                "email": self.email,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true) { _ in /* ignore failures here to avoid blocking verification flow */ }

            // 6) email verification → navigate to the verification screen
            user.sendEmailVerification { _ in
                DispatchQueue.main.async {
                    self.showEmailVerification = true
                }
            }
        }
    }

    // MARK: - Password helpers (tiny, testable predicates)

    /// Returns true when the string contains at least one A–Z character.
    private func containsUppercase(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .uppercaseLetters) != nil
    }

    /// Returns true when the string contains at least one digit or symbol/punctuation.
    private func containsNumberOrSymbol(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .decimalDigits) != nil ||
        text.rangeOfCharacter(from: CharacterSet.symbols.union(.punctuationCharacters)) != nil
    }
}
