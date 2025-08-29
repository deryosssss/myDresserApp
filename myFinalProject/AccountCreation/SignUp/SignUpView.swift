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
struct SignUpView: View {
    @StateObject private var vm = SignupFlowViewModel()
    
    private var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE=1")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 38)

                    Text("Sign Up")
                        .font(AppFont.spicyRice(size: 36))
                        .foregroundColor(.black)
                        .padding(.leading, 32)
                        .padding(.top, 70)

                    Text("CREATE YOUR ACCOUNT")
                        .font(AppFont.spicyRice(size: 16))
                        .foregroundColor(.black.opacity(0.55))
                        .padding(.top, 2)
                        .padding(.leading, 32)

                    Spacer().frame(height: 24)

                    VStack(spacing: 16) {
                        TextField("Email *", text: $vm.email)
                            .aid("signup.email")
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                            .font(AppFont.agdasima(size: 22))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        SecureField("Password *", text: $vm.password)
                            .textContentType(isUITest ? .oneTimeCode : .newPassword)
                            .aid("signup.password")
                            .font(AppFont.agdasima(size: 22))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        SecureField("Confirm Password *", text: $vm.confirmPassword)
                            .aid("signup.confirm")
                            .textContentType(isUITest ? .oneTimeCode : .newPassword)
                            .font(AppFont.agdasima(size: 22))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

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

                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .aid("auth.errorLabel")
                            .foregroundColor(.red)
                            .font(AppFont.agdasima(size: 22))
                            .padding([.horizontal, .top], 32)
                            .transition(.opacity)
                    }

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

                    HStack(alignment: .top, spacing: 8) {
                        Button { vm.agreedToTerms.toggle() } label: {
                            Image(systemName: vm.agreedToTerms ? "checkmark.square" : "square")
                                .foregroundColor(.black)
                                .font(.system(size: 20))
                        }
                        .aid("signup.terms")

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
                                TermsAndConditionsView()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)

                    ContinueButton(
                        title: vm.isLoading ? "Signing Up..." : "CONTINUE",
                        enabled: vm.canContinue && !vm.isLoading,
                        action: vm.signUp,
                        backgroundColor: .white
                    )
                    .aid("signup.continue")

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $vm.goToSignIn) {
                SignInView()
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $vm.showEmailVerification) {
                EmailVerificationFlowView(email: vm.email)
                    .navigationBarBackButtonHidden(true)
            }
            .alert(vm.alertMessage, isPresented: $vm.showSocialAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}
