//
//  RootView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025
//
//  Chooses which top-level screen to show based on auth state.
//

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    // Use a flag or env var ONLY in DEBUG to avoid accidentally forcing SignInView.
    private var isUITest: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-ui-testing")
            || ProcessInfo.processInfo.environment["UI_TEST_MODE"] == "1"
        #else
        return false
        #endif
    }

    var body: some View {
        content
            .environmentObject(auth)
    }

    @ViewBuilder
    private var content: some View {
        if isUITest {
            // UI tests can set: app.launchArguments += ["-ui-testing"]
            SignInView()
        } else if auth.isLoading {
            ZStack {
                Color.white.ignoresSafeArea()
                ProgressView().tint(.black)
            }
        } else if let user = auth.user {
            if user.isEmailVerified {
                MainTabView() // -> contains HomeView
            } else {
                EmailVerificationFlowView(email: user.email ?? "")
                    .task { await auth.reloadUser() }
            }
        } else {
            WelcomeView()
        }
    }
}
