//
//  OnboardingPageView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

/// One page of the onboarding carousel.
/// Renders a centered “card” with title, optional subtitle/image
/// The parent `OnboardingContainerView` supplies the current page index and total count.
struct OnboardingPageView: View {
    // Immutable content model for this page (title/subtitle/optional image).
    let content: OnboardingPageContent
    // Used to draw the page indicator dots and to detect the last page.
    let totalPages: Int
    let currentPage: Int

    // Local navigation trigger to leave onboarding.
    @State private var goToHome = false

    // Fixed card size for a consistent composition across devices.
    // (Keeps the “M” monogram positioning stable.)
    let cardWidth: CGFloat = 270
    let cardHeight: CGFloat = 340
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer() // centers the card vertically a bit lower

                ZStack(alignment: .top) {
                    // ─────────────────────────────────────────────────────────
                    // Main white card with thin black border + soft shadow.
                    // Contains the page title, optional subtitle, image and the final “Continue” button.
                    // ─────────────────────────────────────────────────────────
                    VStack {
                        Spacer().frame(height: 70) // reserved vertical space under the “M” monogram

                        VStack(spacing: 18) {
                            Text(content.title)
                                .font(AppFont.spicyRice(size: 24))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.top, 2)
                                .fixedSize(horizontal: false, vertical: true)

                            if !content.subtitle.isEmpty {
                                Text(content.subtitle)
                                    .font(AppFont.spicyRice(size: 18))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                    .padding(.top, 60)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if currentPage == totalPages - 1 {
                                ContinueButton(
                                    title: "Continue",
                                    enabled: true,
                                    action: { goToHome = true },
                                    backgroundColor: Color.brandYellow
                                )
                                .padding(.top, 40)
                            }
                            
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
                    
                    // ─────────────────────────────────────────────────────────
                    // Decorative “M” monogram layered above the card.
                    // Shadow/blur combo gives a subtle embossed effect.
                    // ─────────────────────────────────────────────────────────
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
                
                // ─────────────────────────────────────────────────────────
                // Page indicator dots: highlight the current page in purple.
                // ─────────────────────────────────────────────────────────
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
            .navigationDestination(isPresented: $goToHome) {
                MainTabView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
