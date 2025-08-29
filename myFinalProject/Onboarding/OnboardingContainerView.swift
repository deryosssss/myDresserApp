//
//  OnboardingContainerView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// High-level container for the multi-page onboarding flow.
/// Responsibilities:
/// • Render a full-bleed background
/// • Host a paged `TabView`
/// • Keep track of the current page via `@State` binding
struct OnboardingContainerView: View {

    /// Source of truth for which onboarding page is visible.
    /// Using `@State` is sufficient here because the page index is view-local UI state.
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Image("onboardingGradient")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)

            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { idx in
                    // Each page is responsible for its own layout.
                    OnboardingPageView(
                        content: onboardingPages[idx],
                        totalPages: onboardingPages.count,
                        currentPage: idx
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}
