//
//  SignInUpViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import SwiftUI

class SignInUpViewModel: ObservableObject {
    @Published var goToSignUp = false
    @Published var goToSignIn = false
    @Published var showSocialAlert = false
    @Published var alertMessage = ""

    // These actions can later be replaced with real sign-in logic
    func signUpTapped() {
        goToSignUp = true
    }

    func signInTapped() {
        goToSignIn = true
    }

    func googleTapped() {
        alertMessage = "Google login coming soon!"
        showSocialAlert = true
    }

    func facebookTapped() {
        alertMessage = "Facebook login coming soon!"
        showSocialAlert = true
    }
}
