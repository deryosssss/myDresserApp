//
//  ItemImageCards.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//
/// Tiny, reusable image-card views used by carousels and grids:
/// - `ImageOnlyCard` renders a single remote image with graceful loading/error states.
/// - `CarouselCard` wraps `ImageOnlyCard` and adds focus-driven scale/opacity/shadow
///   plus a fixed frame—ideal for horizontally scrolling carousels.
///

import SwiftUI

/// Renders just an image with rounded corners, handling AsyncImage states.
/// Background is set on success so transparent PNGs don’t blend with parent.
struct ImageOnlyCard: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let img):
                // Loaded successfully → show the image fitted inside the card
                img.resizable()
                    .scaledToFit()
                    .background(Color(.secondarySystemBackground))
            case .failure(_):
                // Failed to load → neutral placeholder so layout stays stable
                Color(.tertiarySystemFill)
            case .empty:
                // Still loading → inline spinner sized by parent frame
                ProgressView()
            @unknown default:
                // Future-proof fallback
                Color(.tertiarySystemFill)
            }
        }
        // Rounded corners are applied outside AsyncImage so they affect all states
        .clipShape(RoundedRectangle(cornerRadius: ManualLayout.boxCorner))
    }
}

/// Fixed-size card with subtle focus affordances for carousels.
/// - `isFocused` drives a slight scale-up, higher opacity, and a small shadow.
/// - The `contentShape` improves hit testing around the rounded rect.
/// - Animation is scoped to focus changes for snappy, non-intrusive transitions.
struct CarouselCard: View {
    let urlString: String
    let isFocused: Bool
    let height: CGFloat
    let width: CGFloat

    var body: some View {
        ImageOnlyCard(urlString: urlString)
            .frame(width: width, height: height)            // enforce carousel cell size
            .scaleEffect(isFocused ? 1.0 : 0.9)             // focused cell appears slightly larger
            .opacity(isFocused ? 1.0 : 0.78)                // deemphasize non-focused cells
            .shadow(radius: isFocused ? 2 : 0, y: isFocused ? 1 : 0) // subtle lift when focused
            .contentShape(RoundedRectangle(cornerRadius: ManualLayout.boxCorner))
            .animation(.easeInOut(duration: 0.18), value: isFocused) // lightweight focus anim
    }
}
