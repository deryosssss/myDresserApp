//
//  SignInUpViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import SwiftUI

/// ViewModel that drives the Sign In / Sign Up landing screen.
/// Exposes simple navigation flags and placeholder handlers for social auth.
///

class SignInUpViewModel: ObservableObject {
    @Published var goToSignUp = false
    @Published var goToSignIn = false
    @Published var showSocialAlert = false
    @Published var alertMessage = ""
    
    // MARK: - Primary actions

    /// Called when user taps "Sign up".
    /// Flips the navigation flag; the view observes this and pushes SignUpView.
    func signUpTapped() {
        goToSignUp = true
    }
    /// Called when user taps "Sign in".
    /// Flips the navigation flag; the view observes this and pushes SignInView.
    func signInTapped() {
        goToSignIn = true
    }
    /// Placeholder Google action — currently just shows an alert.
    /// Replace with real Google sign-in flow (e.g., GoogleSignIn + Firebase Auth).
    func googleTapped() {
        alertMessage = "Google login coming soon!"
        showSocialAlert = true
    }
    /// Placeholder Facebook action — currently just shows an alert.
    /// Replace with real Facebook Login flow (e.g., FBSDKLoginKit + Firebase Auth).
    func facebookTapped() {
        alertMessage = "Facebook login coming soon!"
        showSocialAlert = true
    }
}
