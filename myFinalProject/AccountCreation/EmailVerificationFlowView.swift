//
//  EmailVerificationFlowView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct EmailVerificationFlowView: View {
    let email: String
    @StateObject private var vm: EmailVerificationViewModel

    init(email: String) {
        self.email = email
        _vm = StateObject(wrappedValue: EmailVerificationViewModel(email: email))
    }

    var body: some View {
        NavigationStack {
            EmailVerificationView(vm: vm)
                .navigationDestination(isPresented: $vm.goToProfileSetup) {
                    ProfileSetupView()
                        .navigationBarBackButtonHidden(true)
                }
        }
    }
}

