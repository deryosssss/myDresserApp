//
//  ForgotPasswordViewMode.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import FirebaseAuth
import SwiftUI

class ForgotPasswordViewModel: ObservableObject {
    @Published var email = ""
    @Published var isLoading = false
    @Published var showConfirmation = false
    @Published var errorMessage = ""

    // Called to dismiss the view (parent can provide this)
    var onDismiss: (() -> Void)?

    var canSend: Bool {
        !email.isEmpty && !isLoading
    }

    func sendPasswordReset() {
        errorMessage = ""
        showConfirmation = false
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return
        }
        isLoading = true
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                // Always show confirmation for privacy (even if error)
                self?.showConfirmation = true
                self?.errorMessage = ""
            }
        }
    }

    func dismiss() {
        onDismiss?()
    }
}
