//
//  SignUpView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
//
import SwiftUI

struct SignUpView: View {
    @StateObject private var vm = SignUpViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 38)

                    // Heading
                    Text("Sign Up")
                        .font(AppFont.spicyRice(size: 36))
                        .foregroundColor(.black)
                        .padding(.leading, 32)
                        .padding(.top, 70)

                    // Subheading
                    Text("CREATE YOUR ACCOUNT")
                        .font(AppFont.spicyRice(size: 16))
                        .foregroundColor(.black.opacity(0.55))
                        .padding(.top, 2)
                        .padding(.leading, 32)

                    Spacer().frame(height: 24)

                    // Input Fields
                    VStack(spacing: 16) {
                        TextField("Email *", text: $vm.email)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                            .font(AppFont.agdasima(size: 18))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        SecureField("Password *", text: $vm.password)
                            .font(AppFont.agdasima(size: 18))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        SecureField("Confirm Password *", text: $vm.confirmPassword)
                            .font(AppFont.agdasima(size: 18))
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .background(Color.white)
                            .cornerRadius(4)

                        //  Social login placeholders (centered)
                        HStack(spacing: 14) {
                            Button(action: {
                                vm.alertMessage = "Google Sign-In coming soon!"
                                vm.showSocialAlert = true
                            }) {
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
                            Button(action: {
                                vm.alertMessage = "Facebook Sign-In coming soon!"
                                vm.showSocialAlert = true
                            }) {
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

                    // Error message
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(AppFont.agdasima(size: 15))
                            .padding([.horizontal, .top], 32)
                            .transition(.opacity)
                    }

                    // Sign In link
                    HStack(spacing: 3) {
                        Spacer()
                        Text("Have an account?  ")
                            .foregroundColor(.black.opacity(0.7))
                            .font(AppFont.agdasima(size: 18))
                        Button(action: {
                            vm.goToSignIn = true
                        }) {
                            Text("Sign in")
                                .font(AppFont.spicyRice(size: 18))
                                .foregroundColor(.black)
                                .underline()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    Spacer().frame(height: 16)

                    // Terms and conditions checkbox
                    HStack(alignment: .top, spacing: 8) {
                        Button(action: {
                            vm.agreedToTerms.toggle()
                        }) {
                            Image(systemName: vm.agreedToTerms ? "checkmark.square" : "square")
                                .foregroundColor(.black)
                                .font(.system(size: 20))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("By signing up, you agree to myDresser's Terms and Conditions.")
                                .font(.custom("Agdasima-Regular", size: 18))
                                .foregroundColor(.black)
                            Button(action: {
                                vm.showTAndCs = true
                            }) {
                                Text("T&C's")
                                    .underline()
                                    .font(.custom("Agdasima-Regular", size: 13).weight(.bold))
                                    .foregroundColor(.blue)
                            }
                            .sheet(isPresented: $vm.showTAndCs) {
                                TermsAndConditionsView()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)

                    // Continue button (reused)
                    ContinueButton(
                        title: vm.isLoading ? "Signing Up..." : "Continue",
                        enabled: vm.canContinue && !vm.isLoading,
                        action: vm.signUp,
                        backgroundColor: .white
                    )

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

