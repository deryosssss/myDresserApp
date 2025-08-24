//
//  HomeView.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//  Updated: 22/08/2025 – CO₂ assumptions store + interactive sheet.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    // MARK: Data sources
    @EnvironmentObject private var wardrobeVM: WardrobeViewModel
    @StateObject private var profileVM = ProfileViewModel()

    // MARK: Screen state and derived metrics
    @StateObject private var vm = HomeViewModel()

    // MARK: CO₂ model (user-tweakable)
    @StateObject private var co2 = CO2SettingsStore()
    @State private var showCO2Settings = false
    @State private var showCO2Details = false

    // MARK: Other sheets
    @State private var showManualSheet = false
    @State private var showAISheet = false
    @State private var showWardrobeSheet = false
    @State private var wardrobeInitialTab: WardrobeView.Tab = .items

    // MARK: Info popovers
    @State private var showDiversityInfo = false
    @State private var showBadgesInfo = false

    // MARK: Layout tokens
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

                    // Header
                    HomeGreetingHeader(
                        displayName: displayName,
                        profileImage: profileVM.profileImage
                    )

                    // Overview
                    HomeOverviewCard(
                        totalItems: vm.totalItems,
                        totalOutfits: wardrobeVM.allOutfits.count,
                        onTapItems: {
                            wardrobeInitialTab = .items
                            showWardrobeSheet = true
                        },
                        onTapOutfits: {
                            wardrobeInitialTab = .outfits
                            showWardrobeSheet = true
                        }
                    )

                    // CO₂ summary (interactive assumptions)
                    HomeCO2Card(
                        outfitsThisMonth: vm.outfitsThisMonth,
                        settings: co2,
                        showSettings: $showCO2Settings,
                        onOpenDetails: { showCO2Details = true }
                    )

                    // New items
                    HomeSectionCard(title: "New Items!") {
                        if vm.recentItems.isEmpty {
                            HomeEmptyRow(text: "No items yet")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vm.recentItems, id: \.id) { item in
                                        NavigationLink {
                                            ItemDetailView(item: item, wardrobeVM: wardrobeVM, onDelete: { })
                                        } label: {
                                            ItemTile(url: item.imageURL)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Diversity
                    HomeDiversitySection(
                        windowLabel: vm.window.rawValue,
                        score: vm.diversityScore,
                        level: vm.diversityLevel,
                        showInfo: $showDiversityInfo
                    )

                    // Usage
                    HomeUsageSection(
                        window: $vm.window,
                        usedCount: vm.usedItemCount,
                        total: vm.totalItems,
                        usagePercent: vm.usagePercent,
                        unused90Count: vm.unused90Count
                    )

                    // Challenge
                    HomeChallengeSection(
                        text: vm.challengeText,
                        spinning: vm.spinning,
                        previewURL: vm.challengeImages.first,
                        hasFocusItem: vm.challengeFocusItem != nil,
                        onSpin: { vm.spinChallenge(from: wardrobeVM) },
                        onAccept: {
                            if let focus = vm.challengeFocusItem {
                                manualStartPinned = focus
                                showManualSheet = true
                            }
                        }
                    )

                    // Badges
                    HomeBadgesSection(
                        totalItems: vm.totalItems,
                        outfitsThisMonth: vm.outfitsThisMonth,
                        co2ThisMonth: Double(vm.outfitsThisMonth) * co2.estimatedKgPerOutfit,
                        streak7: vm.streak7,
                        showInfo: $showBadgesInfo
                    )

                    // CTA
                    Button {
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

            // Data hooks
            .refreshable { wardrobeVM.startAllOutfitsListener() }
            .task { wardrobeVM.startAllOutfitsListener() }

            // Sheets
            .sheet(isPresented: $showManualSheet) {
                ManualCreateSheet(userId: authUID, startPinned: manualStartPinned)
            }
            .sheet(isPresented: $showAISheet) {
                AIStylistSheet(userId: authUID, initialPrompt: aiInitialPrompt)
            }
            .sheet(isPresented: $showCO2Details) {
                CO2InsightsView(outfits: wardrobeVM.allOutfits, factor: co2.estimatedKgPerOutfit)
            }
            .sheet(isPresented: $showCO2Settings) {
                CO2AssumptionsSheet(settings: co2)
            }
            .sheet(isPresented: $showWardrobeSheet) {
                WardrobeView(viewModel: wardrobeVM, initialTab: wardrobeInitialTab)
            }
        }
        .onAppear { vm.refresh(from: wardrobeVM) }
        .onReceive(wardrobeVM.$items) { _ in vm.refresh(from: wardrobeVM) }
        .onReceive(wardrobeVM.$allOutfits) { _ in vm.refresh(from: wardrobeVM) }
        .onChange(of: vm.window) { _ in vm.onWindowChanged() }
    }

    // MARK: Local
    @State private var manualStartPinned: WardrobeItem? = nil
    @State private var aiInitialPrompt: String? = nil
    private var authUID: String { Auth.auth().currentUser?.uid ?? "unknown" }
    private var displayName: String {
        let n = profileVM.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Username" : n
    }
}
