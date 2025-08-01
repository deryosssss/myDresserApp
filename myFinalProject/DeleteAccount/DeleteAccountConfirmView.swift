//
//  DeleteAccountConfirmView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
import SwiftUI
import FirebaseAuth

struct DeleteAccountConfirmView: View {
    @State private var confirmChecked = false
    @State private var showDeletedScreen = false
    @State private var goToHome = false    // <--- New state for HomeView
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer().frame(height: 200)
                    
                    // Warning Text
                    Text("This action is irreversible. You will lose all photos, usage stats, outfits, and AI suggestions.")
                        .font(AppFont.agdasima(size: 24))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                    
                    // Checkbox
                    HStack {
                        Button(action: { confirmChecked.toggle() }) {
                            Image(systemName: confirmChecked ? "checkmark.square" : "square")
                                .foregroundColor(.black)
                                .font(.system(size: 22))
                        }
                        Text("I understand I cannot recover my account")
                            .font(AppFont.agdasima(size: 15))
                            .foregroundColor(.black)
                    }
                    .padding(.top, 140)
                    
                    // Error message if needed
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // Actions Row
                    HStack {
                        Button(action: {
                            goToHome = true      // <--- Go to HomeView
                        }) {
                            Text("Cancel")
                                .font(AppFont.agdasima(size: 17))
                                .foregroundColor(.black)
                        }
                        Spacer()
                        Button(action: {
                            deleteAccount()
                        }) {
                            Text("Delete My Account")
                                .font(AppFont.agdasima(size: 17))
                                .foregroundColor(.red)
                        }
                        .disabled(!confirmChecked)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 200)
                }
                // Navigation for Deleted and Home
                .navigationDestination(isPresented: $showDeletedScreen) {
                    AccountDeletedView()
                        .navigationBarBackButtonHidden(true)
                }
                .navigationDestination(isPresented: $goToHome) {
                    HomeView()
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    func deleteAccount() {
        errorMessage = ""
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You are not signed in."
            return
        }
        user.delete { error in
            if let error = error {
                errorMessage = "Failed to delete account: \(error.localizedDescription)"
            } else {
                showDeletedScreen = true
            }
        }
    }
}



