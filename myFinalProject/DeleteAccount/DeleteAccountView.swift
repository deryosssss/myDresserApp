//
//  DeleteAccountView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// Screen that confirms the user's intent to delete their account.
/// Pattern: **MVVM (View-only)** — this view is purely UI/state orchestration;
/// 
struct DeleteAccountView: View {

    // Local UI state that *drives navigation*. When true, pushes the next screen.
    // Using @State + .navigationDestination keeps navigation declarative and testable.
    @State private var goToLeavingFeedback = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()

                // Primary vertical layout. Left-aligned to match the rest of the app’s headers.
                VStack(alignment: .leading, spacing: 0) {

                    // Top spacer to visually center content without a nav bar title.
                    Spacer().frame(height: 200)

                    // MARK: Heading
                    Text("Delete account?")
                        .font(AppFont.spicyRice(size: 38))  // brand display font
                        .foregroundColor(.black)
                        .padding(.leading, 24)

                    // MARK: Explanatory copy
                    Text("Deleting your account will permanently remove all wardrobe data and access.")
                        .font(AppFont.agdasima(size: 22))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.top, 12)
                        .padding(.trailing, 16)

                    // MARK: Primary CTA
                    Button(action: {
                        goToLeavingFeedback = true
                    }) {
                        Text("continue")
                            .font(AppFont.agdasima(size: 22))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 62)

                    Spacer()
                }
            }
            // MARK: Declarative navigation
            // This binds the boolean to a destination view. Keeps flow logic simple and testable.
            .navigationDestination(isPresented: $goToLeavingFeedback) {
                LeavingFeedbackView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
