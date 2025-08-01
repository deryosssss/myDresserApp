//
//  AccountDeletedView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

struct AccountDeletedView: View {
    @State private var showSignInUp = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                VStack {
                    Spacer()
                    Text("Your account has been\ndeleted. We’re sorry to\nsee you go.")
                        .font(AppFont.spicyRice(size: 28))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
            .onAppear {
                // Show this view for 5 seconds, then go to SignInUpView
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    showSignInUp = true
                }
            }
            .navigationDestination(isPresented: $showSignInUp) {
                SignInUpView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

struct AccountDeletedView_Previews: PreviewProvider {
    static var previews: some View {
        AccountDeletedView()
    }
}
