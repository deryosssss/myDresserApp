//
//  LeavingFeedbackView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// Step 2 in the account deletion flow.
/// Goal: collect lightweight exit feedback (multi-select reasons + optional free text)

struct LeavingFeedbackView: View {

    // Boolean array mirrors `reasons` indices → simple, lightweight multi-select model.
    @State private var selectedReasons: [Bool] = [false, false, false, false]

    // Free-text feedback. Bound to TextEditor below.
    @State private var description = ""

    // Declarative navigation flag (pushes DeleteAccountConfirmView when true).
    @State private var goToDeleteConfirm = false

    // Display strings (UI copy). Keeping them here keeps the view self-contained.
    // TODO: extract to localized strings if you add i18n.
    let reasons = [
        "I am no longer using my account",
        "I don't understand how to use",
        "I have no use to the app",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 148)

                    // MARK: Heading
                    Text("Why are you leaving?")
                        .font(AppFont.spicyRice(size: 34))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.bottom, 16)
                    
                    // MARK: Multi-select reasons
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(reasons.indices, id: \.self) { idx in
                            Button(action: { selectedReasons[idx].toggle() }) {
                                HStack {
                                    Image(systemName: selectedReasons[idx] ? "checkmark.square" : "square")
                                        .foregroundColor(.black)
                                        .font(.system(size: 20))
                                    Text(reasons[idx])
                                        .font(AppFont.agdasima(size: 20))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.bottom, 18)
                    
                    // MARK: Free-text description
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $description)
                            .frame(height: 68)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(4)
                            .padding(.horizontal, 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    .padding(.horizontal, 18)
                            )
                        
                        if description.isEmpty {
                            Text("please add any description you think will find useful")
                                .font(AppFont.agdasima(size: 20))
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.leading, 26)
                                .padding(.top, 14)
                                .allowsHitTesting(false) // lets taps go through to the editor
                        }
                    }
                    .padding(.bottom, 6)
                    .padding(.top, 14)
                    
                    // MARK: Continue CTA
                    Button(action: {
                        goToDeleteConfirm = true
                        // TODO: send `selectedReasons` + `description` to analytics/service in the future to enable users to receive notifications
                    }) {
                        Text("Continue")
                            .font(AppFont.agdasima(size: 22))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    
                    // MARK: Skip link
                    HStack {
                        Spacer()
                        Button(action: {
                            goToDeleteConfirm = true
                        }) {
                            Text("Skip")
                                .font(AppFont.agdasima(size: 28))
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.trailing, 26)
                                .padding(.top, 14)
                        }
                    }
                    
                    Spacer()
                }
            }
            // Declarative routing to the final confirmation screen.
            .navigationDestination(isPresented: $goToDeleteConfirm) {
                DeleteAccountConfirmView()
                    .navigationBarBackButtonHidden(true) // Force linear destructive flow.
            }
        }
    }
}

