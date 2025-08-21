//
//  DressCodeSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//
//  Screen 1 of the “dress code” flow:
//  - user picks a dress code (Casual / Smart Casual / Smart)
//  - we navigate to a results screen that generates outfits constrained to that code
//

import SwiftUI

/// Finite set of supported dress codes.
/// Conforms to Identifiable so we can use it with `navigationDestination(item:)`.
enum DressCodeOption: String, CaseIterable, Identifiable {
    case casual = "Casual"
    case smartCasual = "Smart Casual"
    case smart = "Smart"

    var id: String { rawValue }  // stable ID for navigation & ForEach

    /// Title shown at the top of the results screen.
    var title: String { "\(rawValue) Outfits" }

    /// Lower-cased token used to filter wardrobe items in the VM (simple contains match).
    /// Keeping this here centralizes the mapping between UI label and filter logic.
    var token: String {
        switch self {
        case .casual:       return "casual"
        case .smartCasual:  return "smart casual"
        case .smart:        return "smart"
        }
    }
}

struct DressCodeSuggestionView: View {
    let userId: String

    /// Which pill the user has currently picked (nil means nothing selected yet).
    /// Using `@State` keeps selection local to this screen.
    @State private var selected: DressCodeOption? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text("What is the\nDress code for\nToday ?")
                    .multilineTextAlignment(.center)
                    .font(AppFont.spicyRice(size: 32))
                    .padding(.top, 160)

                // Vertical stack of “choice pills”
                VStack(spacing: 14) {
                    ForEach(DressCodeOption.allCases) { option in
                        Button {
                            selected = option // store selection → turns pill into “selected” state
                        } label: {
                            ChoicePill(
                                title: option.rawValue,
                                selected: selected == option // visual state tied to selection
                            )
                        }
                        .buttonStyle(.plain) // keep pill styling intact (no default blue highlight)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()
            }
            .padding(.bottom, 20)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)

            // When `selected` becomes non-nil, push to results.
            // Using the `item:` variant gives us a clean “optional push” pattern.
            .navigationDestination(item: $selected) { option in
                DressCodeOutfitsView(userId: userId, dressCode: option)
            }
        }
    }
}

/// Rounded “pill” view used for each dress-code choice.
/// Reasoning:
/// - Separate small component keeps the main screen declarative/clean.
/// - Selected state drives both fill and stroke for clear affordance.
private struct ChoicePill: View {
    let title: String
    var selected: Bool

    var body: some View {
        Text(title)
            .font(.custom("Agdasima-Regular", size: 20, relativeTo: .title3))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selected ? Color.brandGreen.opacity(0.25) : Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(selected ? Color.brandGreen : Color.clear, lineWidth: 2)
                    )
            )
    }
}

