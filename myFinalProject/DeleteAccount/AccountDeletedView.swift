//
//  AccountDeletedView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// Simple post-deletion screen.
/// Goal: show a brief farewell message, then route users back to the entry point (SignInUpView).
/// Why this structure:
/// - `NavigationStack`: enables programmatic navigation using boolean state.
/// - `@State showSignInUp`: drives a `.navigationDestination` to avoid imperative pushes.
/// - Timed redirect in `.onAppear`: no user action needed after delete.


struct AccountDeletedView: View {
    /// Local navigation trigger; when true, we navigate to `SignInUpView`.
    @State private var showSignInUp = false
    
    var body: some View {
        NavigationStack { // Modern navigation container that works with `navigationDestination`
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Main message. Using SpicyRice for the brand voice, centered for readability.
                    Text("Your account has been\ndeleted. We’re sorry to\nsee you go.")
                        .font(AppFont.spicyRice(size: 28))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        // (Optional) .accessibilityAddTraits(.isHeader) to announce as a heading
                    
                    Spacer()
                }
            }
            .onAppear {
                // Timed redirect: wait a moment, then navigate back to the auth entry screen.
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    showSignInUp = true
                }
            }
            .navigationDestination(isPresented: $showSignInUp) {
                SignInUpView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
