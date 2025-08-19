//
//  EmailVerificationView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

/// Screen that instructs the user to check their inbox and
/// lets them resend the verification email or confirm they've already verified.

struct EmailVerificationView: View {
    @ObservedObject var vm: EmailVerificationViewModel

    var body: some View {
        ZStack {
            Color.brandYellow.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 180)

                Text("Check your inbox!")
                    .font(AppFont.spicyRice(size: 36))
                    .foregroundColor(.black)
                    .padding(.leading, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    Text("We've sent you a confirmation email at:")
                        .font(AppFont.agdasima(size: 20))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .padding(.leading, 0)

                    Text(vm.email)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -4)
                }
                .padding(.horizontal, 22)

                // Message/Error
                if !vm.message.isEmpty {
                    Text(vm.message)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 18)
                        .padding(.bottom, 5)
                }

                Spacer().frame(height: 30)

                Button(action: { vm.resendEmail() }) {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.white)
                            .cornerRadius(4)
                    } else {
                        Text("Resend")
                            .font(AppFont.agdasima(size: 18))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 32)
                .disabled(vm.isLoading)

                Button(action: { vm.confirmedEmail() }) {
                    Text("I already confirmed my email")
                        .font(AppFont.agdasima(size: 20))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)

                Spacer()
            }
        }
    }
}
