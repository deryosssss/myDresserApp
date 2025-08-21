//
//  FocusableLayerCarousel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//
/// A horizontally scrolling, focusable image carousel for one “layer” (e.g. Tops).
/// - The centered card is the “featured” one
/// - The pin button “locks” the current featured card:
///   • disables scrolling/taps
///   • snaps focus back if momentum changes it
/// - `selectedIndex` stays in sync with the featured card so the parent VM always knows
///   which item is currently picked for this layer.
/// - Uses new iOS 17 scroll APIs when available; falls back to a paged `TabView` on older iOS.
//

import SwiftUI
import UIKit

/// Pin button locks the featured (centered) card.
/// While locked, scroll + taps are disabled and focus is kept on that card.
struct FocusableLayerCarousel: View {
    // MARK: Inputs
    let title: String
    @Binding var locked: Bool                          // external lock state (pin on/off)

    let items: [WardrobeItem]                          // cards to render
    @Binding var selectedIndex: Int                    // VM’s current selection for this layer
    var onTapItem: (WardrobeItem) -> Void              // bubble up taps (to show details)

    // Layout knobs (injected by parent for adaptive sizing)
    let rowHeight: CGFloat
    let cardWidth: CGFloat
    let emptyBoxHeight: CGFloat

    // MARK: Local state
    @State private var focusedID: Int?      // the ID of the currently centered card
    @State private var lockedAtIndex: Int?  // which index we pinned when lock engaged (for snap-back)

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Title + pin button row
            HStack(spacing: 6) {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Button {
                    // Toggle lock. When engaging, capture whatever is currently featured,
                    // snap focus/selection to it, and provide a light haptic.
                    let featured = (focusedID ?? selectedIndex)
                    let willLock = !locked
                    locked = willLock
                    if willLock {
                        lockedAtIndex = featured
                        withAnimation(.easeInOut) {
                            focusedID = featured
                            selectedIndex = featured
                        }
                    } else {
                        lockedAtIndex = nil
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: locked ? "pin.fill" : "pin")
                        .foregroundStyle(locked ? .red : .secondary)
                        .padding(4)
                }
                .accessibilityLabel(locked ? "Unlock current selection" : "Lock current featured item")
                .accessibilityIdentifier("pinButton_\(title)")
            }

            // Content: either an empty placeholder box or the scroller
            if items.isEmpty {
                emptyState
            } else {
                slider
                    .overlay(centerGuide) // subtle vertical line to indicate “center”
                    .mask(edgeFades)      // fade edges so center bias is clear
            }
        }
        // Seed initial focus from the VM’s selection
        .onAppear { focusedID = selectedIndex }

        // Keep VM selection synced to the featured card while **unlocked**.
        .onChange(of: focusedID) { newValue in
            guard !locked else {
                // If locked and inertia changes focus, snap back to the pinned index.
                if let pinned = lockedAtIndex, newValue != pinned {
                    withAnimation(.easeInOut) { focusedID = pinned }
                }
                return
            }
            if let idx = newValue, idx != selectedIndex {
                selectedIndex = idx
            }
        }

        // If the VM changes selection programmatically (e.g., “Roll”), move the carousel to match
        // unless we’re locked (lock wins).
        .onChange(of: selectedIndex) { newValue in
            guard !locked else { return }
            withAnimation(.easeInOut) { focusedID = newValue }
        }

        // If the items change while locked (e.g., filtering), clamp the pinned index so we never
        // point outside bounds, then restore focus/selection to that safe index.
        .onChange(of: items.count) { _ in
            guard locked else { return }
            if let idx = lockedAtIndex, !items.indices.contains(idx) {
                let clamped = max(0, min(idx, items.count - 1))
                lockedAtIndex = clamped
                withAnimation(.easeInOut) {
                    focusedID = clamped
                    selectedIndex = clamped
                }
            }
        }

        // If lock is toggled externally (e.g., a “startPinned” flow in the parent), sync local mirrors.
        .onChange(of: locked) { isLocked in
            if isLocked {
                lockedAtIndex = selectedIndex
                focusedID = selectedIndex
            } else {
                lockedAtIndex = nil
            }
        }
    }

    // MARK: Slider
    @ViewBuilder private var slider: some View {
        if #available(iOS 17.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: ManualLayout.sliderSpacing) {  // NOTE: uses shared layout tokens
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        CarouselCard(
                            urlString: item.imageURL,
                            isFocused: (focusedID ?? selectedIndex) == i, // drives scale/opacity
                            height: rowHeight,
                            width: cardWidth
                        )
                        .id(i) // needed for scrollPosition tracking
                        .onTapGesture {
                            // Don’t allow selecting new items while locked.
                            guard !locked else { return }
                            selectedIndex = i
                            focusedID = i
                            onTapItem(item)
                        }
                    }
                }
                .scrollTargetLayout() // enables view-aligned snapping to card boundaries
            }
            .frame(height: rowHeight)
            // Side margins center the focused card under the guide line.
            .contentMargins(.horizontal, (UIScreen.main.bounds.width - cardWidth)/2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned) // snap to the nearest card
            .scrollPosition(id: $focusedID)     // bind the “featured” card ID
            .allowsHitTesting(!locked)          // disable user input when locked
            .scrollDisabled(locked)             // also stop scrolling when locked
        } else {
            // iOS 16 fallback: paged TabView. Less precise centering but similar UX.
            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    ImageOnlyCard(urlString: item.imageURL)
                        .frame(height: rowHeight)
                        .onTapGesture { guard !locked else { return }; onTapItem(item) }
                        .tag(i)
                        .padding(.vertical, 2)
                }
            }
            .frame(height: rowHeight)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .allowsHitTesting(!locked)
        }
    }

    // Thin vertical indicator to show where “center” is for alignment feedback.
    private var centerGuide: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(width: 1)
            .allowsHitTesting(false)
    }

    // Soft edge fades draw attention to the center card.
    private var edgeFades: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black,  location: 0.08),
                .init(color: .black,  location: 0.92),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: rowHeight)
    }

    // Empty state shown when no items match the current filters/preset.
    private var emptyState: some View {
        RoundedRectangle(cornerRadius: ManualLayout.boxCorner) 
            .fill(Color(.secondarySystemBackground))
            .frame(height: emptyBoxHeight)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "tray")
                    Text("No matching items").font(.footnote)
                    Text("Add items or adjust filters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            )
    }
}
