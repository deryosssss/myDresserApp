
//
//  TermsAndConditionsView.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

/// Simple T&Cs screen shown modally from SignUp.
/// Uses a brand background, a scrollable body, and a single "Back" button.

struct TermsAndConditionsView: View {
    // Dismiss action provided by the presenting context (sheet/stack).
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.brandYellow.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 80)
                Text("Terms & Conditions")
                    .font(AppFont.spicyRice(size: 36))
                    .foregroundColor(.black)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .center)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("1. Introduction")
                            .font(AppFont.agdasima(size: 19))
                            .bold()
                            .foregroundColor(.black)
                        Text("By using MyDresser, you agree to these terms and our privacy policy. Please read them carefully before creating an account.")
                            .font(AppFont.agdasima(size: 16))
                            .foregroundColor(.black)

                        Text("2. Account Registration")
                            .font(AppFont.agdasima(size: 19)).bold().foregroundColor(.black)
                        Text("You must provide a valid email address, create a secure password, and agree to these Terms & Conditions.")
                            .font(AppFont.agdasima(size: 16)).foregroundColor(.black)

                        Text("3. Data & Privacy")
                            .font(AppFont.agdasima(size: 19)).bold().foregroundColor(.black)
                        Text("Your data is securely stored using Firebase. We do not sell your personal information. See our Privacy Policy for details.")
                            .font(AppFont.agdasima(size: 16)).foregroundColor(.black)

                        Text("4. User Conduct")
                            .font(AppFont.agdasima(size: 19)).bold().foregroundColor(.black)
                        Text("You agree not to misuse the app or upload any inappropriate content.")
                            .font(AppFont.agdasima(size: 16)).foregroundColor(.black)

                        Text("5. Termination")
                            .font(AppFont.agdasima(size: 19)).bold().foregroundColor(.black)
                        Text("We reserve the right to terminate your account for violations of these terms.")
                            .font(AppFont.agdasima(size: 16)).foregroundColor(.black)

                        Text("6. Changes to Terms")
                            .font(AppFont.agdasima(size: 19)).bold().foregroundColor(.black)
                        Text("We may update these terms. Continued use of the app constitutes acceptance of the updated terms.")
                            .font(AppFont.agdasima(size: 16)).foregroundColor(.black)

                        Text("7. Contact Us")
                            .font(AppFont.agdasima(size: 19)).bold().foregroundColor(.black)
                        Text("For questions, contact us at support@mydresser.app.")
                            .font(AppFont.agdasima(size: 16)).foregroundColor(.black)

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 26)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Back to Sign Up")
                        .font(AppFont.agdasima(size: 18))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(6)
                        .padding(.horizontal, 30)
                        .padding(.top, 16)
                }
                
                Spacer()
            }
        }
    }
}

