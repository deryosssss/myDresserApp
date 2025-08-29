//
//  SignIn.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// Sign-in screen for existing users.
/// UX goals:
/// • Collect email + password with minimal friction.
/// • Offer “Forgot password” and “Sign up” exits.
/// • Optional social sign-in affordances (currently placeholders).
///
struct SignInView: View {
    /// Screen-scoped state holder. Owns inputs, validation, errors and navigation flags.
    @StateObject private var vm = SignInViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 150)

                    Text("Sign In")
                        .font(AppFont.spicyRice(size: 36))
                        .foregroundColor(.black)
                        .padding(.leading, 24)

                    Text("Sign in to your existing account")
                        .font(AppFont.spicyRice(size: 16))
                        .foregroundColor(.black.opacity(0.55))
                        .padding(.top, 2)
                        .padding(.leading, 24)

                    Spacer().frame(height: 24)

                    // Form fields + social buttons live in a stack to share horizontal padding.
                    VStack(spacing: 16) {
                        TextField("Email *", text: $vm.email)
                            .aid("signin.email")
                            .font(AppFont.agdasima(size: 22))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(4)

                        // Password field: secured entry bound to VM.
                        SecureField("Password *", text: $vm.password)
                            .aid("signin.password")
                            .font(AppFont.agdasima(size: 22))
                            .padding()
                            .background(Color.white)
                            .cornerRadius(4)

                        // Social shortcuts (currently placeholders). Kept side-by-side for balance.
                        HStack(spacing: 14) {
                            Button(action: { /* TODO: Google sign in */ }) {
                                Image("googleIcon")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(4)
                            }
                            Button(action: { /* TODO: Facebook sign in */ }) {
                                Image("facebookIcon")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Inline error from the VM (e.g., invalid creds / network).
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .aid("auth.errorLabel")
                            .foregroundColor(.red)
                            .font(.system(size: 15, weight: .semibold))
                            .padding([.horizontal, .top], 24)
                    }

                    // Secondary actions: Forgot password and Sign up.
                    // These call into the VM which flips boolean nav flags.
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Forgot password ?")
                                .font(AppFont.agdasima(size: 22))
                                .foregroundColor(.black.opacity(0.7))
                            Button(action: { vm.goForgotPassword() }) {
                                Text("Click here")
                                    .font(AppFont.spicyRice(size: 18))
                                    .foregroundColor(.black)
                                    .underline()
                            }
                            .aid("signin.forgot")
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Don't have an account?")
                                .font(AppFont.agdasima(size: 22))
                                .foregroundColor(.black.opacity(0.7))
                            Button(action: { vm.goSignUp() }) {
                                Text("Sign up")
                                    .font(AppFont.spicyRice(size: 18))
                                    .foregroundColor(.black)
                                    .underline()
                            }
                            .aid("signin.signup")
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    Spacer()

                    ContinueButton(
                        title: vm.isLoading ? "Logging in..." : "Continue",
                        enabled: vm.canContinue && !vm.isLoading,
                        action: { vm.signIn() }
                    )
                    .aid("signin.continue")
                    .padding(.bottom, 100)

                    Spacer().frame(height: 10)
                }

                // Navigation is fully driven by VM booleans.
                .navigationDestination(isPresented: $vm.goToForgotPassword) {
                    ForgotPasswordView()
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $vm.goToSignUp) {
                    SignUpView()
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $vm.goToHome) {
                    HomeView()
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }
}
