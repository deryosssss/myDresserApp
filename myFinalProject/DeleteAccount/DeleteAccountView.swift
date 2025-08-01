//
//  DeleteAccountView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

struct DeleteAccountView: View {
    @State private var goToLeavingFeedback = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 200)
                    
                    // Main Heading
                    Text("Delete account?")
                        .font(AppFont.spicyRice(size: 38))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                    
                    // Info text
                    Text("Deleting your account will permanently remove all wardrobe data and access.")
                        .font(AppFont.agdasima(size: 17))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                    
                    // Continue Button
                    Button(action: {
                        goToLeavingFeedback = true
                    }) {
                        Text("continue")
                            .font(AppFont.agdasima(size: 18))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 62)
                    
                    Spacer()
                }
            }
            // Navigation destination
            .navigationDestination(isPresented: $goToLeavingFeedback) {
                LeavingFeedbackView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}



struct DeleteAccountView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteAccountView()
    }
}
