//
//  SignUpView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// Email/password sign-up screen:
/// - Collects credentials and consent.
/// - Delegates all business logic to `SignupFlowViewModel`.
/// - Reacts to published state (errors/loading/navigation) to update the UI.
/// Why MVVM: the View is purely declarative; it observes state and renders,
/// while the ViewModel owns validation, Firebase calls, and navigation flags.

struct SignUpView: View {
    /// `@StateObject` because the View creates and owns the VM instance
    /// (we want it to live for the lifetime of this screen and not be recreated
    /// on every render like a plain `@State` would).
    @StateObject private var vm = SignupFlowViewModel()

    var body: some View {
        NavigationStack { // modern container that manages programmatic navigation destinations
            ZStack {
                Color.brandYellow.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 38)

                    // MARK: - Heading
                    Text("Sign Up")
                        .font(AppFont.spicyRice(size: 36)) // primary display typeface
                        .foregroundColor(.black)
                        .padding(.leading, 32)
                        .padding(.top, 70)

                    // Secondary tagline under the main H1
                    Text("CREATE YOUR ACCOUNT")
                        .font(AppFont.spicyRice(size: 16))
                        .foregroundColor(.black.opacity(0.55))
                        .padding(.top, 2)
                        .padding(.leading, 32)

                    Spacer().frame(height: 24)

                    // MARK: - Inputs
                    // Two-way bindings connect fields to VM state.
                    // Keeping validation in the VM keeps the View uncluttered.
                    VStack(spacing: 16) {
                        TextField("Email *", text: $vm.email)
                            .textInputAutocapitalization(.never) // typical for auth forms
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                            .font(AppFont.agdasima(size: 22))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        SecureField("Password *", text: $vm.password)
                            .font(AppFont.agdasima(size: 22))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        SecureField("Confirm Password *", text: $vm.confirmPassword)
                            .font(AppFont.agdasima(size: 22))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        // MARK: - Social buttons (placeholders)
                        HStack(spacing: 14) {
                            Button {
                                vm.alertMessage = "Google Sign-In coming soon!"
                                vm.showSocialAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image("googleIcon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Spacer()
                                }
                                .frame(height: 44)
                                .background(Color.white)
                                .cornerRadius(4)
                            }

                            Button {
                                vm.alertMessage = "Facebook Sign-In coming soon!"
                                vm.showSocialAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image("facebookIcon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                    Spacer()
                                }
                                .frame(height: 44)
                                .background(Color.white)
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // MARK: - Error message
                    // Single place to surface VM error text (validation or Firebase).
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(AppFont.agdasima(size: 22))
                            .padding([.horizontal, .top], 32)
                            .transition(.opacity)
                    }

                    // MARK: - Already have an account?
                    // Navigates back to Sign In via a boolean navigation destination.
                    HStack(spacing: 3) {
                        Spacer()
                        Text("Have an account?  ")
                            .foregroundColor(.black.opacity(0.7))
                            .font(AppFont.agdasima(size: 22))
                        Button {
                            vm.goToSignIn = true
                        } label: {
                            Text("sign in")
                                .font(AppFont.spicyRice(size: 18))
                                .foregroundColor(.black)
                                .underline()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    Spacer().frame(height: 16)

                    // MARK: - Terms & Conditions
                    // Keeping consent in the VM allows `canContinue` to gate the CTA.
                    HStack(alignment: .top, spacing: 8) {
                        Button { vm.agreedToTerms.toggle() } label: {
                            Image(systemName: vm.agreedToTerms ? "checkmark.square" : "square")
                                .foregroundColor(.black)
                                .font(.system(size: 20))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("By signing up, you agree to myDresser's Terms and Conditions.")
                                .font(AppFont.agdasima(size: 18))
                                .foregroundColor(.black)
                            Button { vm.showTAndCs = true } label: {
                                Text("T&C's")
                                    .underline()
                                    .font(AppFont.agdasima(size: 16).weight(.bold))
                                    .foregroundColor(.blue)
                            }
                            .sheet(isPresented: $vm.showTAndCs) {
                                TermsAndConditionsView() // separate, reusable screen
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)

                    // MARK: - Continue CTA
                    // Uses a shared component; enabled state is driven by VM.canContinue and isLoading.
                    ContinueButton(
                        title: vm.isLoading ? "Signing Up..." : "CONTINUE",
                        enabled: vm.canContinue && !vm.isLoading,
                        action: vm.signUp,
                        backgroundColor: .white
                    )

                    Spacer()
                }
            }
            // MARK: - Programmatic Navigation
            // Navigation is driven by boolean flags in the VM to keep the View dumb.
            .navigationDestination(isPresented: $vm.goToSignIn) {
                SignInView()
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $vm.showEmailVerification) {
                // ViewModel sets this to true after creating the user and sending the email.
                EmailVerificationFlowView(email: vm.email)
                    .navigationBarBackButtonHidden(true)
            }
            // MARK: - Placeholder Alerts
            .alert(vm.alertMessage, isPresented: $vm.showSocialAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

