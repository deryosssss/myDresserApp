//
//  SignInViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import FirebaseAuth
import SwiftUI

/// MVVM: ViewModel that powers the Sign-In screen.
/// - Holds user inputs and UI flags as @Published state so the View can reactively update.
/// - Performs Firebase Auth sign-in and translates low-level errors into friendly messages.
/// - Exposes boolean navigation flags the View binds to for routing (no navigation logic in the View).
///

class SignInViewModel: ObservableObject {
    // MARK: - Inputs & UI state

    /// Raw form inputs bound from the View's text fields.
    @Published var email = ""
    @Published var password = ""
    /// One-line message shown under the form when something goes wrong.
    @Published var errorMessage = ""
    /// Toggles loading spinners / disables buttons during the network request.
    @Published var isLoading = false
    
    // MARK: - Navigation flags (the View binds to these)
    /// Push "Forgot password" when true.
    @Published var goToForgotPassword = false
    /// Push "Sign up" when true.
    @Published var goToSignUp = false
    /// Push "Home" on successful sign-in.
    @Published var goToHome = false

    // MARK: - Derived state
    /// Enables the primary CTA only when both fields are non-empty.
    /// (We still validate format/length in `signIn()` for robustness.)
    var canContinue: Bool {
        !email.isEmpty && !password.isEmpty
    }

    // MARK: - Actions
    /// Attempts Firebase email+password sign-in.
    /// Flow:
    /// 1) Clear any stale error.
    /// 2) Lightweight client-side validation (email contains '@', password length).
    /// 3) Flip `isLoading`, call Firebase.
    /// 4) In the callback, hop to the main queue, stop loading, map errors → user-friendly text.
    /// 5) On success, flip `goToHome` which the View observes to navigate.
    func signIn() {
        errorMessage = ""

        // Basic guardrails before hitting the network.
        guard email.contains("@"), password.count >= 6 else {
            errorMessage = "Please enter a valid email and password."
            return
        }

        isLoading = true

        // Use [weak self] to avoid a retain cycle if the VM outlives the request.
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error as NSError? {
                    // Translate common AuthErrorCode values into clearer copy.
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
                        // Fallback to Firebase's message for any edge cases.
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    // Happy path: flip the nav flag. The View will navigate to Home.
                    self.goToHome = true
                }
            }
        }
    }

    // MARK: - Navigation intents (kept tiny for readability/testability)

    /// Trigger navigation to Forgot Password.
    func goForgotPassword() { goToForgotPassword = true }

    /// Trigger navigation to Sign Up.
    func goSignUp() { goToSignUp = true }
}
