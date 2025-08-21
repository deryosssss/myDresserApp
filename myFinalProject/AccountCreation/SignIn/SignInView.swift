//
//  SignIn.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
import SwiftUI

/// Sign-in screen for existing users:
/// - collects email/password
/// - offers social sign-in shortcuts
/// - links to Forgot Password and Sign Up flows
/// - on success navigates to Home

struct SignInView: View {
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
                    
                    VStack(spacing: 16) {
                        TextField("Email *", text: $vm.email)
                            .font(AppFont.agdasima(size: 22))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(4)
                        
                        SecureField("Password *", text: $vm.password)
                            .font(AppFont.agdasima(size: 22))
                            .padding()
                            .background(Color.white)
                            .cornerRadius(4)
                        
                        HStack(spacing: 14) {
                            Button(action: { /* Google sign in */ }) {
                                Image("googleIcon")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(4)
                            }
                            Button(action: { /* Facebook sign in */ }) {
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
                    
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 15, weight: .semibold))
                            .padding([.horizontal, .top], 24)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Forgot password ?")
                                .font(AppFont.agdasima(size: 22))
                                .foregroundColor(.black.opacity(0.7))
                            Button(action: {
                                vm.goForgotPassword()
                            }) {
                                Text("Click here")
                                    .font(AppFont.spicyRice(size: 18))
                                    .foregroundColor(.black)
                                    .underline()
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Don't have an account?")
                                .font(AppFont.agdasima(size: 22))
                                .foregroundColor(.black.opacity(0.7))
                            Button(action: {
                                vm.goSignUp()
                            }) {
                                Text("Sign up")
                                    .font(AppFont.spicyRice(size: 18))
                                    .foregroundColor(.black)
                                    .underline()
                            }
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
                    .padding(.bottom, 100)
                    Spacer().frame(height: 10)
                }
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

