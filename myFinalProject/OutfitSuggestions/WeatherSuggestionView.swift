//
//  WeatherSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//


import SwiftUI

private enum WXLayout {
    static let cardCorner: CGFloat = 14
    static let cardPadding: CGFloat = 12
    static let gridSpacing: CGFloat = 12
    static let thumbSize: CGSize = .init(width: 110, height: 130)
    static let buttonHeight: CGFloat = 28
}

private let fullDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

struct WeatherSuggestionView: View {
    @StateObject private var vm: WeatherSuggestionViewModel

    // preview sheet
    @State private var previewItems: [WardrobeItem] = []
    @State private var showPreview = false

    // If you let the user pick another day, bind it here.
    @State private var selectedDate: Date? = nil

    /// Pass temperature (e.g. "23°C") and an optional weather icon image from your OpenWeather VM.
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
                        // ===== Header (centered, slightly higher) =====
                        header
                            .padding(.horizontal)
                            .padding(.top, 2)  // a little higher than before

                        // ===== Cards =====
                        if vm.cards.isEmpty && !vm.isLoading {
                            emptyState
                                .padding(.horizontal)
                                .padding(.top, 24)
                        } else {
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
                            ProgressView().padding(.vertical, 24)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.loadInitial() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
            .sheet(isPresented: $showPreview) {
                OutfitPreviewSheet(
                    items: previewItems,
                    onClose: { showPreview = false },
                    onSave: { name, occasion, date, description, isFav in
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
    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Group {
                    if let icon = vm.icon {
                        icon
                            .resizable()
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "cloud.sun")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 36))
                    }
                }
                Text(vm.temperature)
                    .font(AppFont.spicyRice(size: 36))
                    .baselineOffset(2)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Text((selectedDate ?? vm.currentDate), formatter: fullDateFormatter)
                .font(AppFont.spicyRice(size: 20))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity) // centers the stack in the scroll width
    }

    // MARK: Empty state
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

private struct SuggestionCard: View {
    let candidate: WeatherOutfitCandidate
    var onSkip: () -> Void
    var onSave: () -> Void

    private let cols = [
        GridItem(.flexible(), spacing: WXLayout.gridSpacing),
        GridItem(.flexible(), spacing: WXLayout.gridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: cols, spacing: WXLayout.gridSpacing) {
                ForEach(candidate.orderedItems, id: \.id) { item in
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: WXLayout.thumbSize.width, height: WXLayout.thumbSize.height)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .empty:
                            ProgressView()
                                .frame(width: WXLayout.thumbSize.width, height: WXLayout.thumbSize.height)
                        default:
                            Color(.tertiarySystemFill)
                                .frame(width: WXLayout.thumbSize.width, height: WXLayout.thumbSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

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
            RoundedRectangle(cornerRadius: WXLayout.cardCorner)
                .fill(Color(.systemGray6))
        )
    }
}
