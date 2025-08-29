//
//  StatsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

// SwiftUI dashboard that summarises the user’s wardrobe and usage over a selected time window

struct StatsView: View {
    // Shared data VM from your app
    @EnvironmentObject private var wardrobeVM: WardrobeViewModel
    // Screen VM (MVVM)
    @StateObject private var vm = StatsViewModel()

    // Disclosure toggles (view-only)
    @State private var showWhatsIn = true
    @State private var showUsage   = true

    // Drill-down sheet
    @State private var showFilteredSheet = false
    @State private var filteredTitle = ""
    @State private var filteredItems: [WardrobeItem] = []

    // MARK: - Layout tokens (view-only)
    enum UX {
        static let pagePadding: CGFloat = 16
        static let sectionGap: CGFloat = 16
        static let stripThumbSize = CGSize(width: 86, height: 96)
        static let cardCorner: CGFloat = 12
        static let cardPadding: CGFloat = 12
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.sectionGap) {

                    Text("My Stats")
                        .font(AppFont.spicyRice(size: 28))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    Picker("", selection: $vm.window) {
                        ForEach(StatsViewModel.Window.allCases) { w in Text(w.rawValue).tag(w) }
                    }
                    .pickerStyle(.segmented)

                    usageCard

                    // New items
                    StatsSectionCard(title: "New items") {
                        if vm.recentItems.isEmpty {
                            StatsEmptyRow(text: "No items yet")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(vm.recentItems, id: \.id) { item in
                                        NavigationLink {
                                            ItemDetailView(item: item, wardrobeVM: wardrobeVM, onDelete: { })
                                        } label: {
                                            ItemThumb(url: item.imageURL, size: UX.stripThumbSize)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    // New outfits
                    StatsSectionCard(title: "New outfits") {
                        if vm.recentOutfits.isEmpty {
                            StatsEmptyRow(text: "No outfits yet")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(vm.recentOutfitsRows) { row in
                                        NavigationLink {
                                            OutfitDetailView(outfit: row.outfit)
                                                .environmentObject(wardrobeVM)
                                        } label: {
                                            CollageCard(urls: row.outfit.itemImageURLs)
                                                .frame(width: 120, height: 96)
                                                .background(Color.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    // What's in my wardrobe
                    StatsSectionDisclosure(title: "What's in my wardrobe", isExpanded: $showWhatsIn)
                    if showWhatsIn {
                        StatsSectionCard(title: "Categories") {
                            NiceDonutChart(
                                segments: vm.categorySegments,
                                height: 240,
                                inset: 8,
                                legendMin: 132
                            ) { seg in
                                filteredTitle = seg.label
                                filteredItems = vm.itemsForCategory(seg.label, in: wardrobeVM.items)
                                showFilteredSheet = true
                            }
                        }
                        StatsSectionCard(title: "Colour") {
                            NiceDonutChart(
                                segments: vm.colourSegments,
                                height: 240,
                                inset: 8,
                                legendMin: 132
                            ) { seg in
                                filteredTitle = seg.label
                                filteredItems = vm.itemsForColour(seg.label, in: wardrobeVM.items)
                                showFilteredSheet = true
                            }
                        }
                    }

                    // My usage
                    StatsSectionDisclosure(title: "My usage", isExpanded: $showUsage)
                    if showUsage {
                        StatsSectionCard(title: "Most worn items") {
                            ItemStrip(items: vm.mostWornItems, vm: wardrobeVM, thumbSize: UX.stripThumbSize)
                        }
                        StatsSectionCard(title: "Least worn items") {
                            ItemStrip(items: vm.leastWornItems, vm: wardrobeVM, thumbSize: UX.stripThumbSize)
                        }
                        StatsSectionCard(title: "Oldest items") {
                            ItemStrip(items: vm.oldestItems, vm: wardrobeVM, thumbSize: UX.stripThumbSize)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, UX.pagePadding)
                .padding(.bottom, 24)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                wardrobeVM.startAllOutfitsListener()
                vm.refresh(from: wardrobeVM)
            }
            .onReceive(wardrobeVM.$items) { _ in vm.refresh(from: wardrobeVM) }
            .onReceive(wardrobeVM.$allOutfits) { _ in vm.refresh(from: wardrobeVM) }
            .onChange(of: vm.window) { _ in vm.refresh(from: wardrobeVM) }
            .sheet(isPresented: $showFilteredSheet) {
                ItemGridSheet(title: filteredTitle, items: filteredItems, vm: wardrobeVM)
            }
        }
    }
}

// MARK: - Usage Card
private extension StatsView {
    var usageCard: some View {
        StatsSectionCard(title: "Wardrobe usage") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(vm.usedItemCount) used")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(max(vm.totalItems - vm.usedItemCount, 0)) not used")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(vm.usagePercent)%")
                        .font(.headline)
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 22)

                    GeometryReader { geo in
                        let w = geo.size.width * CGFloat(vm.usagePercent) / 100.0
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brandGreen.opacity(0.65))
                            .frame(width: max(0, w), height: 22)
                            .animation(.easeInOut(duration: 0.4), value: vm.usagePercent)
                    }
                }
                .frame(height: 22)
            }
            .padding(.vertical, 2)
        }
    }
}
