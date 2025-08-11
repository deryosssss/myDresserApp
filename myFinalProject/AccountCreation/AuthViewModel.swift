//
//  AuthViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//
import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isLoading = true
    @Published var authError: String?

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // If you want verification emails to use device language:
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

    func signIn(email: String, password: String) async {
        authError = nil
        do { _ = try await Auth.auth().signIn(withEmail: email, password: password) }
        catch { authError = error.localizedDescription }
    }

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

    func signOut() {
        authError = nil
        do { try Auth.auth().signOut() }           // RootView will switch back to WelcomeView
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
