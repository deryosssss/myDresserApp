//
//  DressCodeSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//
//


import SwiftUI

enum DressCodeOption: String, CaseIterable, Identifiable {
    case casual = "Casual"
    case smartCasual = "Smart Casual"
    case smart = "Smart"

    var id: String { rawValue }

    /// Title for the results screen
    var title: String { "\(rawValue) Outfits" }

    /// Lowercased token used for filtering (in the VM)
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

    // Which pill is currently selected on this screen
    @State private var selected: DressCodeOption? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text("What is the\nDress code for\nToday ?")
                    .multilineTextAlignment(.center)
                    .font(AppFont.spicyRice(size: 32))
                    .padding(.top, 160)

                VStack(spacing: 14) {
                    ForEach(DressCodeOption.allCases) { option in
                        Button {
                            selected = option      // turn this pill green…
                        } label: {
                            ChoicePill(
                                title: option.rawValue,
                                selected: selected == option // …only the picked one is green
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()
            }
            .padding(.bottom, 20)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // Push the results view when a selection exists
            .navigationDestination(item: $selected) { option in
                DressCodeOutfitsView(userId: userId, dressCode: option)
            }
        }
    }
}

/// Rounded “pill” like in your mock.
/// Default: grey. Selected: brandGreen background + stroke.
/// Text uses Agdasima.
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

#Preview {
    DressCodeSuggestionView(userId: "demo-user")
}
