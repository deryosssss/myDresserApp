//
//  HelpSheetView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 19/08/2025.
//


import SwiftUI

struct HelpSheetView: View {
    // Personalization
    var username: String = ""
    var supportEmail: String = "support@example.com"

    // Optional callbacks to deep-link to parts of your app
    var onAddItem: () -> Void = {}
    var onOpenWardrobe: () -> Void = {}
    var onOpenFilters: () -> Void = {}
    var onOpenWeather: () -> Void = {}
    var onOpenAICreator: () -> Void = {}

    // Local UI state
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("showTipsOnLaunch") private var showTipsOnLaunch: Bool = true
    @State private var search: String = ""
    @State private var showCopied: Bool = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "v\(v) (\(b))"
    }

    // Simple searchable tips list
    private let tips: [String] = [
        "Long-press an item to quickly favorite it.",
        "Use the filter button to combine color, season and dress code.",
        "Tap the heart on an outfit to mark it as a favorite.",
        "Pull down to refresh lists after making changes on another device.",
        "Use Weather Suggestions to get outfits that match the forecast.",
        "You can edit tags, colors and more from an item’s detail screen.",
        "Create outfits manually or with AI; both save to your wardrobe.",
        "Sort items by Newest/Oldest or A–Z from the sort menu.",
        "On the outfit preview, rename, set an occasion and mark favorite before saving.",
        "Under Stats you’ll see last worn date and usage hints."
    ]

    private var filteredTips: [String] {
        guard !search.isEmpty else { return tips }
        let q = search.lowercased()
        return tips.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Welcome
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hey \(username.isEmpty ? "there" : username)! 👋")
                            .font(.headline)
                        Text("Here’s a quick guide to help you get the most out of your smart wardrobe.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Show quick tips on launch", isOn: $showTipsOnLaunch)
                        .toggleStyle(.switch)
                        .padding(.top, 4)
                }

                // Quick actions
                Section("Quick actions") {
                    Button {
                        dismiss()
                        onAddItem()
                    } label: { Label("Add a new item", systemImage: "plus.circle.fill") }

                    Button {
                        dismiss()
                        onOpenWardrobe()
                    } label: { Label("Open My Wardrobe", systemImage: "rectangle.grid.2x2") }

                    Button {
                        dismiss()
                        onOpenFilters()
                    } label: { Label("Filter & sort items", systemImage: "slider.horizontal.3") }

                    Button {
                        dismiss()
                        onOpenWeather()
                    } label: { Label("Weather suggestions", systemImage: "cloud.sun") }

                    Button {
                        dismiss()
                        onOpenAICreator()
                    } label: { Label("Create outfit with AI", systemImage: "sparkles") }
                }

                // Adding & tagging
                Section("Add & tag items") {
                    LabeledRow(
                        icon: "camera.viewfinder",
                        title: "Add from camera, gallery or web",
                        detail: "We auto-categorise and tag colors, length, fit and more. You can edit anything before saving."
                    )
                    LabeledRow(
                        icon: "wand.and.stars",
                        title: "Auto-categorised? Review before save",
                        detail: "Tap the chips (Category, Style, Colours…) to adjust. Toggle “Favorite” if it’s a staple."
                    )
                    LabeledRow(
                        icon: "paintpalette",
                        title: "Colours with swatches",
                        detail: "We store color names and hex codes so you can filter by color and see swatches across the app."
                    )
                }

                // Outfits
                Section("Outfits") {
                    LabeledRow(
                        icon: "square.grid.2x2",
                        title: "Collage previews",
                        detail: "Outfits show as a 2–6 tile collage. Tap to see details, tags and items used."
                    )
                    LabeledRow(
                        icon: "heart",
                        title: "Favorite & delete",
                        detail: "Tap the heart to favorite. Use the trash in the detail view to delete."
                    )
                    LabeledRow(
                        icon: "text.badge.plus",
                        title: "Outfit meta",
                        detail: "Give your outfit a name, pick an occasion, set a date and add a description."
                    )
                }

                // Filters, sorting & search
                Section("Search, filter & sort") {
                    LabeledRow(
                        icon: "magnifyingglass",
                        title: "Search",
                        detail: "Find items by category, style, tags or color name."
                    )
                    LabeledRow(
                        icon: "slider.horizontal.3",
                        title: "Filter",
                        detail: "Filter by color, season, dress code, size and more. Combine filters for laser-focused results."
                    )
                    LabeledRow(
                        icon: "arrow.up.arrow.down",
                        title: "Sort",
                        detail: "Sort by Newest, Oldest, A–Z or Z–A. Items and outfits respect your favorite toggle and filters."
                    )
                }

                // Weather suggestions
                Section("Weather suggestions") {
                    LabeledRow(
                        icon: "cloud.sun.rain",
                        title: "Forecast-aware",
                        detail: "Suggestions adapt to temp and rain, and keep items coherent within the same dress code."
                    )
                    LabeledRow(
                        icon: "tray.and.arrow.down",
                        title: "Save what you like",
                        detail: "Tap Save to review the outfit, tweak details and add it to your wardrobe."
                    )
                }

                // Tips (searchable)
                if !filteredTips.isEmpty {
                    Section("Tips & tricks") {
                        ForEach(filteredTips, id: \.self) { tip in
                            Text("• \(tip)")
                        }
                    }
                }

                // FAQ
                Section("FAQ") {
                    FAQRow(
                        question: "Why don’t I see my new item?",
                        answer: "Make sure you tapped Save after reviewing. Also check you’re signed in and online. Pull down to refresh."
                    )
                    FAQRow(
                        question: "Why do outfits show fewer tiles?",
                        answer: "We display up to six item images per outfit. If an outfit has fewer items, we fill just those tiles."
                    )
                    FAQRow(
                        question: "How do I change an item’s colors/tags later?",
                        answer: "Open the item, then tap the chips (Colours, Tags, Style...) to edit. Changes save instantly."
                    )
                    FAQRow(
                        question: "Can I export or delete my data?",
                        answer: "Yes. You can remove items, outfits, or delete your account in Profile. Exports are coming soon."
                    )
                }

                // Troubleshooting
                Section("Troubleshooting") {
                    Text("• App looks out of date → pull-to-refresh the list.\n• Upload stuck → check connection and try again.\n• Signed out unexpectedly → sign back in and your data will re-sync.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Privacy & data
                Section("Privacy & data") {
                    Text("Your items and outfits are stored securely in your account. You can delete any item, outfit or your entire account at any time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Contact
                Section("Contact & feedback") {
                    Button {
                        let subject = "Wardrobe Support"
                        let body = "Hi team,%0D%0A%0D%0A"
                        if let url = URL(string: "mailto:\(supportEmail)?subject=\(subject)&body=\(body)") {
                            openURL(url)
                        }
                    } label: {
                        Label("Email support", systemImage: "envelope")
                    }

                    Button {
                        UIPasteboard.general.string = supportEmail
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation { showCopied = false }
                        }
                    } label: {
                        Label("Copy support email", systemImage: "doc.on.doc")
                    }
                    .foregroundColor(.secondary)
                }

                // App info
                Section("App info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Search tips")
            .overlay(alignment: .bottom) {
                if showCopied {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Text("Copied").padding(.horizontal, 12))
                        .frame(height: 34)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Reusable rows

private struct LabeledRow: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FAQRow: View {
    let question: String
    let answer: String
    @State private var expanded = false
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(answer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        } label: {
            Text(question).font(.subheadline)
        }
    }
}
