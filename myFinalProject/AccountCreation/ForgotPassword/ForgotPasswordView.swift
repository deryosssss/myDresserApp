//
//  ForgotPasswordView.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

/// Password-reset screen (MVVM).
/// - View owns only **UI state** and delegates logic to `ForgotPasswordViewModel`.
/// - Flow:
///   1) User enters email and taps **Send Reset Link**.
///   2) ViewModel triggers Firebase Auth password reset.
///   3) On success, UI switches to a confirmation state with **Back to sign in**.
/// - Accessibility/UX: clear empty/confirm states, disabled controls while loading.
struct ForgotPasswordView: View {

    /// Screen-scoped ViewModel. `@StateObject` ensures a single instance per view lifecycle.
    @StateObject var vm = ForgotPasswordViewModel()

    /// Dismiss closure from the environment to navigate back (e.g., to sign-in).
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Brand background keeps the view visually consistent with the auth flow.
            Color.brandYellow.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 148)

                // Title: large, brand typeface.
                Text("Forgot password")
                    .font(AppFont.spicyRice(size: 36))
                    .foregroundColor(.black)
                    .padding(.leading, 24)

                // Subtitle + state-dependent instructional copy.
                VStack(alignment: .center, spacing: 2) {
                    Text("Enter your email")
                        .font(AppFont.spicyRice(size: 20))
                        .foregroundColor(.black.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .padding(.leading, 24)

                    if vm.showConfirmation {
                        // Post-send confirmation explaining next steps.
                        Text("If your email is registered, a reset link has been sent. After you reset your password, please sign in with your new password.")
                            .font(AppFont.agdasima(size: 22))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 18)
                            .padding(.bottom, 25)
                            .padding(.horizontal, 10)
                    } else {
                        // Pre-send guidance (no PII leakage; phrased conditionally).
                        Text("If your email is registered, a reset link will be sent")
                            .font(AppFont.agdasima(size: 22))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 18)
                            .padding(.bottom, 25)
                    }
                }
                .padding(.horizontal, 8)

                // Email field is only visible before confirmation.
                if !vm.showConfirmation {
                    /// Note: consider `textInputAutocapitalization(.never)` on iOS 15+.
                    TextField("Email *", text: $vm.email)
                        .font(AppFont.agdasima(size: 22))
                        .autocapitalization(.none)     // kept for compatibility; see note above
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(4)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .disabled(vm.isLoading)        // prevent edits while sending
                }

                // Inline error (validation or network) shown above actions.
                if !vm.errorMessage.isEmpty {
                    Text(vm.errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                // Actions depend on state: after send → single back CTA; before send → send + back.
                if vm.showConfirmation {
                    // After successful request: single path back to sign-in.
                    Button(action: { dismiss() }) {
                        Text("Back to sign in")
                            .font(AppFont.agdasima(size: 22))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(4)
                            .underline() // underline the label for affordance
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                } else {
                    // Primary action: triggers ViewModel to send the Firebase reset email.
                    Button(action: {
                        vm.sendPasswordReset()
                    }) {
                        if vm.isLoading {
                            // Visual feedback during async work; also disables inputs above.
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text("Send Reset Link")
                                .font(AppFont.agdasima(size: 22))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(vm.canSend ? Color.white : Color.white.opacity(0.7)) // subtle disabled state
                                .cornerRadius(4)
                        }
                    }
                    .disabled(!vm.canSend)       // guards: non-empty & valid email, not loading
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Secondary action: navigate back without sending.
                    Button("Back to sign in") { dismiss() }
                        .font(AppFont.spicyRice(size: 18))
                        .foregroundColor(.black)
                        .underline()
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    // NOTE: `.underline()` is a `Text` modifier; attached to `Button` it may be ignored.
                    // If you need guaranteed underline, use a label closure and apply `.underline()` on the `Text`.
                }

                Spacer()
            }
        }
        .onAppear {
            // Allows the ViewModel to request dismissal (e.g., after success).
            vm.onDismiss = { dismiss() }
        }
    }
}
