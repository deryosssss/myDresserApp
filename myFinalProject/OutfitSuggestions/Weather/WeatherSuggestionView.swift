//
//  WeatherSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//

import SwiftUI

// MARK: - Layout
// Centralize “magic numbers” for easy tuning and consistent spacing/sizing across the screen.
private enum WXLayout {
    static let cardCorner: CGFloat = 14
    static let cardPadding: CGFloat = 12
    static let gridSpacing: CGFloat = 12
    static let thumbSize: CGSize = .init(width: 110, height: 130)
    static let buttonHeight: CGFloat = 28
}

// Shared date formatter for the header date.
// Doing this once (static) avoids recreating DateFormatter (which is expensive) on every render.
private let fullDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

/// Presents weather-aware outfit suggestions as cards:
/// • Header shows temperature + icon + date
/// • List of suggestion cards (Skip/Save)
/// • On Save → opens preview sheet to confirm + persist
struct WeatherSuggestionView: View {
    // Orchestrates fetching suggestions and persisting the chosen outfit.
    // StateObject ensures a single VM instance for the view’s lifetime (no re-creation on re-render).
    @StateObject private var vm: WeatherSuggestionViewModel

    // Local UI state used only by this view (preview sheet).
    @State private var previewItems: [WardrobeItem] = []
    @State private var showPreview = false

    // Optional override for the date shown in the header (kept for future calendar selection).
    @State private var selectedDate: Date? = nil

    /// Injects context (user/location/weather) and header visuals.
    /// The VM is created here so dependencies are passed once and retained by @StateObject.
    init(
        userId: String,
        lat: Double,
        lon: Double,
        isRaining: Bool,
        temperature: String,
        icon: Image? = nil,
        date: Date = Date()
    ) {
        _vm = StateObject(wrappedValue: WeatherSuggestionViewModel(
            userId: userId,
            lat: lat,
            lon: lon,
            isRaining: isRaining,
            temperature: temperature,
            icon: icon,
            date: date
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // ===== Header (centered) =====
                        header
                            .padding(.horizontal)
                            .padding(.top, 2)

                        // ===== Cards =====
                        if vm.cards.isEmpty && !vm.isLoading {
                            // Empty state appears only when not loading and no results.
                            emptyState
                                .padding(.horizontal)
                                .padding(.top, 24)
                        } else {
                            // Render each suggestion card. Save → open preview; Skip → ask VM for a new one.
                            ForEach(vm.cards) { card in
                                SuggestionCard(
                                    candidate: card,
                                    onSkip: { Task { await vm.skip(card.id) } },
                                    onSave: {
                                        previewItems = card.orderedItems
                                        showPreview = true
                                    }
                                )
                            }
                        }

                        if vm.isLoading {
                            // Lightweight activity indicator while VM is building cards.
                            ProgressView().padding(.vertical, 24)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            // Kick off initial load once when the view appears.
            // Using .task (vs .onAppear) plays nicer with SwiftUI’s concurrency.
            .task { await vm.loadInitial() }

            // Simple error alert; tapping OK clears the VM message.
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }

            // Preview sheet lets the user name/confirm before persisting the outfit to Firestore.
            .sheet(isPresented: $showPreview) {
                OutfitPreviewSheet(
                    items: previewItems,
                    onClose: { showPreview = false },
                    onSave: { name, occasion, date, description, isFav in
                        // Save via VM (async), then close the sheet.
                        Task {
                            await vm.saveOutfit(
                                name: name,
                                occasion: occasion,
                                description: description,
                                date: date,
                                isFavorite: isFav,
                                items: previewItems
                            )
                            showPreview = false
                        }
                    }
                )
            }
        }
    }

    // MARK: Header (centered)
    /// Temperature + icon + date. Falls back to a system icon if none provided.
    /// `selectedDate` (if set) overrides the VM date in the header.
    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Group {
                    if let icon = vm.icon {
                        icon
                            .resizable()
                            .frame(width: 42, height: 42)
                    } else {
                        // Fallback SF Symbol so the UI doesn’t look empty.
                        Image(systemName: "cloud.sun")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 36))
                    }
                }
                Text(vm.temperature)
                    .font(AppFont.spicyRice(size: 36))
                    .baselineOffset(2) // visually aligns text with the icon
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Text((selectedDate ?? vm.currentDate), formatter: fullDateFormatter)
                .font(AppFont.spicyRice(size: 20))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Empty state
    /// Friendly prompt to populate wardrobe or retry loading
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tshirt")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No weather suggestions yet")
                .font(.headline)
            Text("Make sure you have items in your wardrobe.\nYou can also try again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                // Re-run the generator; useful after adding items.
                Task { await vm.loadInitial() }
            } label: {
                Text("Try again")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(minWidth: 140, minHeight: WXLayout.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandGreen)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6))
        )
    }
}

// MARK: - Card

/// Renders a grid of thumbnails for the candidate items + Skip/Save actions.
/// Uses a 2-column LazyVGrid for a tidy, scannable layout.
private struct SuggestionCard: View {
    let candidate: WeatherOutfitCandidate
    var onSkip: () -> Void
    var onSave: () -> Void

    // 2-up grid for item thumbnails
    private let cols = [
        GridItem(.flexible(), spacing: WXLayout.gridSpacing),
        GridItem(.flexible(), spacing: WXLayout.gridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnails (ordered for a tidy look, provided by candidate.orderedItems).
            LazyVGrid(columns: cols, spacing: WXLayout.gridSpacing) {
                ForEach(candidate.orderedItems, id: \.id) { item in
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: WXLayout.thumbSize.width, height: WXLayout.thumbSize.height)
                                .background(Color(.secondarySystemBackground)) // soft white frame
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .empty:
                            // While loading, show a light progress placeholder.
                            ProgressView()
                                .frame(width: WXLayout.thumbSize.width, height: WXLayout.thumbSize.height)
                        default:
                            // Network/error fallback to keep the grid shape intact.
                            Color(.tertiarySystemFill)
                                .frame(width: WXLayout.thumbSize.width, height: WXLayout.thumbSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            // Actions: Skip gives a different combo; Save opens the confirmation sheet.
            HStack(spacing: 10) {
                Button(role: .cancel, action: onSkip) {
                    Text("Skip")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: WXLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)

                Button(action: onSave) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: WXLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
            }
        }
        .padding(WXLayout.cardPadding)
        .background(
            // Card look that matches other sections in the app (soft gray panel).
            RoundedRectangle(cornerRadius: WXLayout.cardCorner)
                .fill(Color(.systemGray6))
        )
    }
}
