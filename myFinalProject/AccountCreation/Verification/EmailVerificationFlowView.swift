//
//  EmailVerificationFlowView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

// Takes the user’s email from signup.
// Creates and stores an EmailVerificationViewModel.
// Displays an EmailVerificationView.
// When verification succeeds (goToProfileSetup = true), automatically navigates to ProfileSetupView.
// Disables the back button so users can’t skip the setup.

import SwiftUI
/// A container view that manages the email verification process.
/// It initializes an `EmailVerificationViewModel` with the given email
/// and handles navigation to the profile setup screen once verification is complete.
///

struct EmailVerificationFlowView: View {
    let email: String
    @StateObject private var vm: EmailVerificationViewModel

    init(email: String) {
        self.email = email
        _vm = StateObject(wrappedValue: EmailVerificationViewModel(email: email))
    }

    var body: some View {
        NavigationStack {
            // Show the email verification screen, passing in the ViewModel.
            EmailVerificationView(vm: vm)
            // If `vm.goToProfileSetup` becomes true, navigate to the Profile Setup screen.
                .navigationDestination(isPresented: $vm.goToProfileSetup) {
                    ProfileSetupView()
                        .navigationBarBackButtonHidden(true)
                }
        }
    }
}

