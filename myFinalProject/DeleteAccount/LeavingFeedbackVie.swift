//
//  LeavingFeedbackView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

struct LeavingFeedbackView: View {
    @State private var selectedReasons: [Bool] = [false, false, false, false]
    @State private var description = ""
    @State private var goToDeleteConfirm = false

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
                    
                    // Heading
                    Text("Why are you leaving?")
                        .font(AppFont.spicyRice(size: 34))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.bottom, 16)
                    
                    // Reasons checkboxes
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(reasons.indices, id: \.self) { idx in
                            Button(action: { selectedReasons[idx].toggle() }) {
                                HStack {
                                    Image(systemName: selectedReasons[idx] ? "checkmark.square" : "square")
                                        .foregroundColor(.black)
                                        .font(.system(size: 20))
                                    Text(reasons[idx])
                                        .font(AppFont.agdasima(size: 16))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.bottom, 18)
                    
                    // Description box
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
                                .font(AppFont.agdasima(size: 15))
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.leading, 26)
                                .padding(.top, 14)
                        }
                    }
                    .padding(.bottom, 6)
                    .padding(.top, 14)
                    
                    // Continue button (your style, assumed from previous usage)
                    Button(action: {
                        goToDeleteConfirm = true
                    }) {
                        Text("Continue")
                            .font(AppFont.agdasima(size: 18))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    
                    // Skip link
                    HStack {
                        Spacer()
                        Button(action: {
                            goToDeleteConfirm = true
                        }) {
                            Text("Skip")
                                .font(AppFont.agdasima(size: 15))
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.trailing, 26)
                                .padding(.top, 14)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationDestination(isPresented: $goToDeleteConfirm) {
                DeleteAccountConfirmView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

struct LeavingFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        LeavingFeedbackView()
    }
}
