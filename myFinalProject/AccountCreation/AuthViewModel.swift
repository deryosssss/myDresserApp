//
//  AuthViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//

// Tracks the signed-in Firebase user state in real-time.
// Manages sign-in, sign-up, and sign-out using Firebase Auth.
// Handles email verification and user data refreshing.
// Publishes changes to SwiftUI views so they react automatically.

import Foundation
import FirebaseAuth

// Main actor ensures all UI updates happen on the main thread.
// ObservableObject allows SwiftUI views to react to changes in @Published properties.
@MainActor
final class AuthViewModel: ObservableObject {
    // The currently signed-in Firebase user (optional because user may be nil if signed out)
    @Published var user: FirebaseAuth.User?
    // Indicates whether the authentication process is loading (e.g., while waiting for Firebase)
    @Published var isLoading = true
    // Stores any authentication-related error messages for display in the UI
    @Published var authError: String?

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // Configure Firebase Auth to send verification emails in the device's language
        Auth.auth().useAppLanguage()

        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.isLoading = false
        }
    }

    deinit {
        if let listener { Auth.auth().removeStateDidChangeListener(listener) }
    }

    // MARK: - Email/Password
    
    /// Signs in an existing user using email and password.
    func signIn(email: String, password: String) async {
        authError = nil
        do { _ = try await Auth.auth().signIn(withEmail: email, password: password) }
        catch { authError = error.localizedDescription }
    }
    
    /// Creates a new user account and sends a verification email.
    func signUp(email: String, password: String) async {
        authError = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.user = result.user
            // Kick off verification email immediately (optional to call here or in your SignupFlowViewModel)
            try await sendEmailVerification()
        } catch {
            authError = error.localizedDescription
        }
    }
    /// Signs the current user out.
    func signOut() {
        authError = nil
        do { try Auth.auth().signOut() }
        // Once signed out, UI should transition to WelcomeView automatically
        catch { authError = error.localizedDescription }
    }

    // MARK: - Email verification helpers

    /// Reloads the Firebase user so `isEmailVerified` reflects the latest state.
    func reloadUser() async {
        guard let u = Auth.auth().currentUser else { return }
        do {
            try await u.reload()
            self.user = Auth.auth().currentUser
        } catch {
            // not fatal; you could surface this if you want
        }
    }

    /// Sends a verification email to the current user.
    func sendEmailVerification() async throws {
        guard let u = Auth.auth().currentUser else { return }
        try await u.sendEmailVerification()
    }
}



