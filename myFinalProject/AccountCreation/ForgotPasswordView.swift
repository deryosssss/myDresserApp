//
//  ForgotPasswordView.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

/// A view that allows users to request a password reset via email.
/// Displays confirmation and navigation options after sending the reset link.
///
/// Before sending → shows email field and “Send Reset Link” button.
/// After sending → shows a confirmation message and a single “Back to sign in” button.
/// Uses ForgotPasswordViewModel to handle logic for sending reset emails via Firebase Auth.

struct ForgotPasswordView: View {
    @StateObject var vm = ForgotPasswordViewModel()
    @Environment(\.dismiss) var dismiss // For going back

    var body: some View {
        ZStack {
            Color.brandYellow.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 148)
                Text("Forgot password")
                    .font(AppFont.spicyRice(size: 36))
                    .foregroundColor(.black)
                    .padding(.leading, 24)

                VStack(alignment: .center, spacing: 2) {
                    Text("Enter your email")
                        .font(AppFont.spicyRice(size: 16))
                        .foregroundColor(.black.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .padding(.leading, 24)

                    if vm.showConfirmation {
                        Text("If your email is registered, a reset link has been sent. After you reset your password, please sign in with your new password.")
                            .font(AppFont.agdasima(size: 17))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 18)
                            .padding(.bottom, 25)
                    } else {
                        Text("If your email is registered, a reset link will be sent")
                            .font(AppFont.agdasima(size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 18)
                            .padding(.bottom, 25)
                    }
                }
                .padding(.horizontal, 8)

                if !vm.showConfirmation {
                    TextField("Email *", text: $vm.email)
                        .font(AppFont.agdasima(size: 16))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(4)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .disabled(vm.isLoading)
                }

                if !vm.errorMessage.isEmpty {
                    Text(vm.errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                if vm.showConfirmation {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Back to sign in")
                            .font(AppFont.agdasima(size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(4)
                            .underline()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                } else {
                    Button(action: {
                        vm.sendPasswordReset()
                    }) {
                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text("Send Reset Link")
                                .font(AppFont.agdasima(size: 18))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(vm.canSend ? Color.white : Color.white.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                    .disabled(!vm.canSend)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Button("Back to sign in") {
                        dismiss()
                    }
                    .font(AppFont.spicyRice(size: 18))
                    .foregroundColor(.black)
                    .underline()
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                }
                Spacer()
            }
        }
        .onAppear {
            vm.onDismiss = { dismiss() }
        }
    }
}
