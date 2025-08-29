//
//  ForgotPasswordViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import FirebaseAuth
import SwiftUI

/// MVVM: ViewModel that drives the **Forgot Password** screen.
/// - Owns only UI state (email, loading, confirmation, error).
/// - Exposes a single command (`sendPasswordReset`) that talks to Firebase Auth.
class ForgotPasswordViewModel: ObservableObject {

    // MARK: - Input & UI state

    /// Two-way bound to the email TextField in the View.
    @Published var email = ""
    /// True while the reset request is in flight; used to disable inputs and show a spinner.
    @Published var isLoading = false
    /// When true, the View switches to the post-send confirmation state.
    @Published var showConfirmation = false
    /// Optional inline error (validation/network). We still show confirmation for privacy (see below).
    @Published var errorMessage = ""
    /// Optional callback the View installs so the VM can request dismissal on success.
    var onDismiss: (() -> Void)?
    /// Enables the primary button. Cheap gate to avoid empty submits or double-clicks.
    /// (Format validation is done again inside `sendPasswordReset()`.)
    var canSend: Bool {
        !email.isEmpty && !isLoading
    }

    // MARK: - Actions

    /// Triggers Firebase to send a password-reset email for `email`.
    ///
    /// Security & UX decisions:
    /// - **Email enumeration protection**: We **always** flip `showConfirmation = true`
    ///   regardless of Firebase’s response. This prevents attackers from learning whether
    ///   an email exists in the system.
    /// - We still do light client-side validation to help users catch obvious typos.
    /// - Network/UI updates are marshalled back to the main queue.
    func sendPasswordReset() {
        // Reset transient UI before validating
        errorMessage = ""
        showConfirmation = false

        // Minimal email sanity check to avoid needless network calls.
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true

        // Firebase Auth call; capture self weakly to avoid retain cycles.
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                // Stop spinner and *always* show confirmation (privacy-preserving).
                self?.isLoading = false
                self?.showConfirmation = true

                // We intentionally hide backend errors to avoid leaking account existence.
                // If you want telemetry, you can log `error` to your analytics pipeline here.
                self?.errorMessage = ""
            }
        }
    }

    /// Allows the ViewModel to close the screen (View injects this via `onAppear`).
    func dismiss() {
        onDismiss?()
    }
}
