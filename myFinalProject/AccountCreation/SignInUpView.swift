//
//  SignInUpView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// Landing screen that lets the user choose Sign up / Sign in,
/// or trigger social auth. Navigation is driven by the ViewModel's booleans.

struct SignInUpView: View {
    @StateObject private var vm = SignInUpViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                VStack(spacing: 36) {
                    Spacer()
                    
                    // MyDresser logo (Spicy Rice)
                    ZStack {
                        Text("MyDresser")
                            .font(AppFont.spicyRice(size: 54))
                            .foregroundColor(.black)
                            .appDropShadow()
                            .offset(x: 2, y: 2)
                        Text("MyDresser")
                            .font(AppFont.spicyRice(size: 54))
                            .foregroundColor(.white)
                            .appDropShadow()
                    }
                    .padding(.bottom, 24)
                    
                    VStack(spacing: 18) {
                        // Sign Up Button
                        Button(action: { vm.signUpTapped() }) {
                            Text("Sign up")
                                .foregroundColor(.black)
                                .font(AppFont.agdasima(size: 20))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(6)
                        }
                        
                        // Sign In Button
                        Button(action: { vm.signInTapped() }) {
                            Text("Sign in")
                                .foregroundColor(.black)
                                .font(AppFont.agdasima(size: 20))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(6)
                        }
                        
                        // Social Login Buttons
                        HStack(spacing: 14) {
                            Button(action: { vm.googleTapped() }) {
                                Image("googleIcon")
                                    .resizable()
                                    .frame(width: 26, height: 26)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }
                            Button(action: { vm.facebookTapped() }) {
                                Image("facebookIcon")
                                    .resizable()
                                    .frame(width: 26, height: 26)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            // Navigation destinations:
            .navigationDestination(isPresented: $vm.goToSignUp) {
                SignUpView()
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $vm.goToSignIn) {
                SignInView()
                    .navigationBarBackButtonHidden(true)
            }
            .alert(vm.alertMessage, isPresented: $vm.showSocialAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

