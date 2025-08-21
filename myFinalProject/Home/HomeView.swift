//
//  HomeView.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI
import FirebaseAuth

/// Home dashboard composed of small, testable subviews:
/// - Pulls wardrobe + profile data from shared VMs
/// - Shows greeting, CO₂ card, recent items, diversity, usage, challenge, badges
/// - Hosts "Create outfits" CTA and two modal flows (manual / AI)
struct HomeView: View {
    // MARK: Data sources
    /// Shared wardrobe state injected at app root (single source of truth for items/outfits).
    @EnvironmentObject private var wardrobeVM: WardrobeViewModel
    /// Local profile image/name loader; StateObject so it lives for the screen lifetime.
    @StateObject private var profileVM = ProfileViewModel()

    // MARK: Screen state and derived metrics
    /// Presentation logic + derived KPIs (recent items, usage %, streaks, etc).
    @StateObject private var vm = HomeViewModel()

    // MARK: Sheet state
    /// Modal flags + payloads for manual/AI flows. Kept local to avoid polluting the VM.
    @State private var showManualSheet = false
    @State private var showAISheet = false
    @State private var manualStartPinned: WardrobeItem? = nil
    @State private var aiInitialPrompt: String? = nil

    // MARK: Info popover state
    /// Small, ephemeral booleans for contextual help—view-only state.
    @State private var showStreakInfo = false
    @State private var showDiversityInfo = false
    @State private var showBadgesInfo = false
    @State private var showCO2Info = false

    // MARK: Layout tokens (centralized spacing/sizing for visual consistency)
    enum UX {
        static let sectionGap: CGFloat = 16
        static let cardCorner: CGFloat = 12
        static let cardPadding: CGFloat = 12
        static let thumb = CGSize(width: 120, height: 120)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.sectionGap) {

                    // MARK: Header (profile + streak)
                    HomeGreetingHeader(
                        displayName: displayName,
                        monthlyHeadline: vm.monthlyHeadline,
                        streak: vm.streak7,
                        profileImage: profileVM.profileImage,
                        showStreakInfo: $showStreakInfo
                    )

                    // MARK: CO₂ saved card (with info popover)
                    HomeCO2Card(
                        kilograms: vm.co2SavedThisMonth,
                        showInfo: $showCO2Info
                    )

                    // MARK: New items carousel
                    HomeSectionCard(title: "New Items!") {
                        if vm.recentItems.isEmpty {
                            HomeEmptyRow(text: "No items yet")
                        } else {
                            // Horizontal scroller with tappable item tiles → details.
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vm.recentItems, id: \.id) { item in
                                        NavigationLink {
                                            // Navigate to item details; pass shared VM for actions.
                                            ItemDetailView(item: item, wardrobeVM: wardrobeVM, onDelete: { })
                                        } label: {
                                            ItemTile(url: item.imageURL)
                                        }
                                        .buttonStyle(.plain) // avoids tinted link styling
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // MARK: Style diversity (progress + info)
                    HomeDiversitySection(
                        windowLabel: vm.window.rawValue,
                        score: vm.diversityScore,
                        level: vm.diversityLevel,
                        showInfo: $showDiversityInfo
                    )

                    // MARK: Usage (windowed stats + progress bar + unused count)
                    HomeUsageSection(
                        window: $vm.window,
                        usedCount: vm.usedItemCount,
                        total: vm.totalItems,
                        usagePercent: vm.usagePercent,
                        unused90Count: vm.unused90Count
                    )

                    // MARK: Challenge spinner (fun CTA with optional accept → manual creator)
                    HomeChallengeSection(
                        text: vm.challengeText,
                        spinning: vm.spinning,
                        previewURL: vm.challengeImages.first,
                        hasFocusItem: vm.challengeFocusItem != nil,
                        onSpin: { vm.spinChallenge(from: wardrobeVM) },
                        onAccept: {
                            // If a focus item was picked, pre-pin it in the manual flow.
                            if let focus = vm.challengeFocusItem {
                                manualStartPinned = focus
                                showManualSheet = true
                            }
                        }
                    )

                    // MARK: Badges (with definitions sheet)
                    HomeBadgesSection(
                        totalItems: vm.totalItems,
                        outfitsThisMonth: vm.outfitsThisMonth,
                        co2ThisMonth: vm.co2SavedThisMonth,
                        streak7: vm.streak7,
                        showInfo: $showBadgesInfo
                    )

                    // MARK: Bottom CTA (AI stylist)
                    Button {
                        // Ask the VM for a context-aware prompt, then open the AI sheet.
                        aiInitialPrompt = vm.aiPrompt()
                        showAISheet = true
                    } label: {
                        Text("Create outfits")
                            .font(AppFont.spicyRice(size: 18))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.brandBlue)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)

            // MARK: Data refresh hooks
            // Pull fresh outfits feed when user pulls to refresh.
            .refreshable { wardrobeVM.startAllOutfitsListener() }
            // Also start listener on first load for live updates.
            .task { wardrobeVM.startAllOutfitsListener() }

            // MARK: Modal flows
            .sheet(isPresented: $showManualSheet) {
                // Manual creator; optionally seeds with a pinned item from the challenge.
                ManualCreateSheet(userId: authUID, startPinned: manualStartPinned)
            }
            .sheet(isPresented: $showAISheet) {
                // AI stylist; seeded with a VM-built prompt for better results.
                AIStylistSheet(userId: authUID, initialPrompt: aiInitialPrompt)
            }
        }
        // MARK: Reactive data sync
        // Recompute derived UI whenever upstream data or the selected window changes.
        .onAppear { vm.refresh(from: wardrobeVM) }                       // initial populate
        .onReceive(wardrobeVM.$items) { _ in vm.refresh(from: wardrobeVM) }      // items changed
        .onReceive(wardrobeVM.$allOutfits) { _ in vm.refresh(from: wardrobeVM) } // outfits changed
        .onChange(of: vm.window) { _ in vm.onWindowChanged() }                    // window picker
    }

    // MARK: - Local helpers

    /// Defensive fallback in case Auth isn't ready yet.
    private var authUID: String { Auth.auth().currentUser?.uid ?? "unknown" }

    /// Prefer profile username when present; keeps the header friendly when it's blank.
    private var displayName: String {
        let n = profileVM.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Username" : n
    }
}
