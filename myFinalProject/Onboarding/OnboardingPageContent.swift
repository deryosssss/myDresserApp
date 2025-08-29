//
//  OnboardingPageContent.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// Lightweight model for a single onboarding screen.
/// Kept as a plain struct so the onboarding flow is data-driven (easy to reorder or A/B test).
struct OnboardingPageContent {
    /// Primary headline for the page (supports line breaks with \n).
    let title: String
    /// Optional supporting copy shown under the title.
    let subtitle: String
    /// Optional asset name for the page illustration. `nil` → no image row rendered.
    let imageName: String?
    /// Allows per-page headline sizing without hard-coding font modifiers in the view.
    let titleFontSize: CGFloat
}

let onboardingPages: [OnboardingPageContent] = [
    .init(
        title: "Welcome to\nMyDresser",
        subtitle: "What can you do on My Dresser?",
        imageName: nil,
        titleFontSize: 55
    ),
    .init(
        title: "Add a new clothing item using our AI recognition system",
        subtitle: "",
        imageName: "onboardingAddClothes", 
        titleFontSize: 24
    ),
    .init(
        title: "Manually Assemble Outfits or Receive Daily AI Outfit Suggestions",
        subtitle: "",
        imageName: "onboardingOutfitAI",
        titleFontSize: 24
    ),
    .init(
        title: "Create your wardrobe and browse your wardrobe",
        subtitle: "",
        imageName: "onboardingWardrobe",
        titleFontSize: 24
    ),
    .init(
        title: "View your wardrobe analytics dashboard!",
        subtitle: "",
        imageName: "onboardingAnalytics",
        titleFontSize: 24
    ),
    .init(
        title: "You are now ready!",   
        subtitle: "Go explore!",
        imageName: nil,
        titleFontSize: 45
    )
]
