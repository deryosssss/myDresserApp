//
//  RootView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025
//
//  1) Chooses which top-level screen to show based on auth state (loading → spinner, signed-in → app, signed-out → welcome).
//  2) If signed-in but email not verified, shows the verification flow and keeps status fresh via `reloadUser()`.
//

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel  // shared auth state (user, loading, actions)

    @ViewBuilder
    var body: some View {
        if auth.isLoading {
            // Still resolving auth session → show a neutral loading screen
            ZStack {
                Color.white.ignoresSafeArea()
                ProgressView().tint(.black)
            }
        } else if let user = auth.user {
            // Signed in
            if user.isEmailVerified {
                // Email verified → go to main app tabs
                MainTabView()
                    .environmentObject(auth) // pass auth down the tree
            } else {
                // Signed in but not verified → show verification flow
                EmailVerificationFlowView(email: user.email ?? "")
                    .environmentObject(auth)
                    .task { await auth.reloadUser() }   // keep verification status up to date
            }
        } else {
            // Not signed in → welcome/onboarding
            WelcomeView()
                .environmentObject(auth)
        }
    }
}
