//
//  OnboardingPageContent.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
import SwiftUI

struct OnboardingPageContent {
    let title: String
    let subtitle: String
    let imageName: String? // nil if not used
    let titleFontSize: CGFloat
}

// Your content for each onboarding screen
let onboardingPages: [OnboardingPageContent] = [
    .init(title: "Welcome to\nMyDresser", subtitle: "What can you do on My Dresser?", imageName: nil, titleFontSize: 55),
    .init(title: "Add a new clothing item using our AI recognition system", subtitle: "", imageName: "onboardingAddClothes", titleFontSize: 24),
    .init(title: "Manually Assemble Outfits or Receive Daily AI Outfit Suggestions", subtitle: "", imageName: "onboardingOutfitAI", titleFontSize: 24),
    .init(title: "Create your wardrobe and browse your wardrobe", subtitle: "", imageName: "onboardingWardrobe", titleFontSize: 24),
    .init(title: "View your wardrobe analytics dashboard!", subtitle: "", imageName: "onboardingAnalytics", titleFontSize: 24),
    .init(title: "You are now already!", subtitle: "Go explore!", imageName: nil, titleFontSize: 45)
]
