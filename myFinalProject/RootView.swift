//
//  RootView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//
import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    @ViewBuilder
    var body: some View {
        if auth.isLoading {
            ZStack {
                Color.white.ignoresSafeArea()
                ProgressView().tint(.black)
            }
        } else if let user = auth.user {
            if user.isEmailVerified {
                MainTabView()

                    .environmentObject(auth)
            } else {
                EmailVerificationFlowView(email: user.email ?? "")
                    .environmentObject(auth)
                    .task { await auth.reloadUser() }   // ✅ keep status fresh
            }
        } else {
            WelcomeView()
                .environmentObject(auth)
        }
    }
}
