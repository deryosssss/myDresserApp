//
//  OnboardingPageView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct OnboardingPageView: View {
    let content: OnboardingPageContent
    let totalPages: Int
    let currentPage: Int

    @State private var goToHome = false

    let cardWidth: CGFloat = 270
    let cardHeight: CGFloat = 340
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .top) {
                    // Main Card
                    VStack {
                        Spacer().frame(height: 70) // Space for the "M"
                        VStack(spacing: 18) {
                            // Title with padding
                            Text(content.title)
                                .font(AppFont.spicyRice(size: 24))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.top, 2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Subtitle with padding, if present
                            if !content.subtitle.isEmpty {
                                Text(content.subtitle)
                                    .font(AppFont.spicyRice(size: 18))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                    .padding(.top, 60)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            // Continue Button ONLY on last page
                            if currentPage == totalPages - 1 {
                                ContinueButton(
                                    title: "Continue",
                                    enabled: true,
                                    action: {
                                        goToHome = true
                                    },
                                    backgroundColor: Color.brandYellow
                                )
                                .padding(.top, 40)
                            }
                            
                            // Image (if provided)
                            if let img = content.imageName {
                                Image(img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 280, maxHeight: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 1))
                                    .shadow(radius: 1)
                                    .padding(.top, 6)
                            }
                            
                            Spacer()
                        }
                        .frame(width: cardWidth, height: cardHeight, alignment: .top)
                    }
                    .background(Color.white)
                    .cornerRadius(1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 4)
                    
                    // "M" logo, always same place/size, overlaps card
                    HStack {
                        Spacer()
                        ZStack {
                            Text("M")
                                .font(AppFont.spicyRice(size: 120))
                                .foregroundColor(.black)
                                .offset(x: 3, y: 5)
                                .blur(radius: 0.6)
                            Text("M")
                                .font(AppFont.spicyRice(size: 110))
                                .foregroundColor(.white)
                                .appDropShadow()
                        }
                        .frame(height: 75)
                        Spacer()
                    }
                    .offset(y: -40)
                }
                
                // Dots indicator
                HStack(spacing: 12) {
                    ForEach(0..<totalPages, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentPage ? Color.purple : Color.purple.opacity(0.22))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 36)
                Spacer()
            }
            // Navigation to HomeView when finished
            .navigationDestination(isPresented: $goToHome) {
                MainTabView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
