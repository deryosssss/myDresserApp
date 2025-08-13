//
//  PromptSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//

import SwiftUI

// Simple layout constants for this screen
private enum PSLayout {
    static let titleTopPadding: CGFloat = 24
    static let fieldHeight: CGFloat = 48
    static let actionSize: CGFloat = 54
    static let corner: CGFloat = 12
}

struct PromptSuggestionView: View {
    let userId: String

    @State private var draftPrompt: String = ""
    @State private var goToResults: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("What are you\nFeeling Today ?")
                .multilineTextAlignment(.center)
                .font(AppFont.spicyRice(size: 36))
                .padding(.top, PSLayout.titleTopPadding)

            HStack(spacing: 12) {
                TextField("Start Typing", text: $draftPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .frame(minHeight: PSLayout.fieldHeight)
                    .disableAutocorrection(true)

                Button {
                    let prompt = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !prompt.isEmpty else {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        return
                    }
                    goToResults = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .frame(width: PSLayout.actionSize, height: PSLayout.actionSize)
                        .background(Color.brandGreen.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: PSLayout.corner))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Text("Example Prompt: all black outfit that is stylish and smart")
                .font(.footnote)
                .foregroundColor(.brandPink)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Programmatic push to results screen
        .background(
            NavigationLink(
                "",
                isActive: $goToResults,
                destination: {
                    PromptResultsView(userId: userId, initialPrompt: draftPrompt)
                }
            )
            .hidden()
        )
    }
}

#Preview {
    NavigationStack {
        PromptSuggestionView(userId: "demo-user")
    }
}
