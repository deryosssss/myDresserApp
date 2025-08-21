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
            // Background: an asset image stretched to fill the screen.
            // `scaledToFill` ensures no letterboxing; combined with
            // `.edgesIgnoringSafeArea(.all)` to extend under safe areas.
            // (Modern alternative: `.ignoresSafeArea()`.)
            Image("onboardingGradient")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)

            // Paged content: `TabView` with `selection` binding so we can
            // both read and programmatically set the current page if needed.
            TabView(selection: $currentPage) {
                // Drive pages from an external data source:
                // `onboardingPages` is an array of models defined elsewhere.
                // Using indices keeps tags stable and avoids `Identifiable` conformance here.
                ForEach(0..<onboardingPages.count, id: \.self) { idx in
                    // Each page is responsible for its own layout.
                    // We pass: the page content model, total page count (for dots/progress),
                    // and the zero-based index for local logic/animations.
                    OnboardingPageView(
                        content: onboardingPages[idx],
                        totalPages: onboardingPages.count,
                        currentPage: idx
                    )
                    // Tag is required for a `selection`-driven TabView;
                    // it must match the type bound to `selection` (Int here).
                    .tag(idx)
                }
            }
            // Use the Page style for horizontal swiping.
            // We hide the default index to allow a custom indicator inside `OnboardingPageView`.
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}
