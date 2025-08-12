//
//  ManualSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//


import SwiftUI

// Fixed constants (everything else adapts)
private enum Layout {
    static let topPadding: CGFloat = 20
    static let boxCorner: CGFloat = 14
    static let buttonHeight: CGFloat = 34
    static let sliderSpacing: CGFloat = 14
}

/// Computed sizing based on how many layers are shown
private struct AdaptiveSize {
    let rowHeight: CGFloat
    let cardWidth: CGFloat
    let sectionSpacing: CGFloat
    let emptyBoxHeight: CGFloat

    static func forLayers(_ count: Int) -> AdaptiveSize {
        switch count {
        case ...1:
            return .init(rowHeight: 240, cardWidth: 190, sectionSpacing: 18, emptyBoxHeight: 210)
        case 2:
            return .init(rowHeight: 210, cardWidth: 170, sectionSpacing: 16, emptyBoxHeight: 185)
        case 3:
            return .init(rowHeight: 165, cardWidth: 138, sectionSpacing: 12, emptyBoxHeight: 150) // smaller
        case 4:
            return .init(rowHeight: 138, cardWidth: 120, sectionSpacing: 10, emptyBoxHeight: 125) // smaller
        case 5:
            return .init(rowHeight: 116, cardWidth: 106, sectionSpacing: 9,  emptyBoxHeight: 104) // smaller
        case 6:
            return .init(rowHeight: 108, cardWidth: 98,  sectionSpacing: 8,  emptyBoxHeight: 96)  // smaller
        default: // 7+
            return .init(rowHeight: 100, cardWidth: 92,  sectionSpacing: 8,  emptyBoxHeight: 90)
        }
    }
}

struct ManualSuggestionView: View {
    @StateObject private var vm: ManualSuggestionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingFilter = false
    @State private var selectedPreset: LayerPreset
    @State private var selectedItemForDetail: WardrobeItem?

    init(userId: String) {
        let preset: LayerPreset = .three_TopBottomShoes
        _vm = StateObject(wrappedValue: ManualSuggestionViewModel(userId: userId, preset: preset.kinds))
        _selectedPreset = State(initialValue: preset)
    }

    private var sizing: AdaptiveSize { AdaptiveSize.forLayers(vm.layers.count) }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    content
                        .padding(.top, Layout.topPadding)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .task { await vm.loadAll() }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
            .sheet(item: $selectedItemForDetail) { item in
                ItemDetailView(
                    item: item,
                    wardrobeVM: WardrobeViewModel(),
                    onDelete: {
                        selectedItemForDetail = nil
                        Task { await vm.loadAll() }
                    }
                )
            }
        }
    }

    // MARK: - Content
    private var content: some View {
        VStack(alignment: .leading, spacing: sizing.sectionSpacing) {
            VStack(spacing: sizing.sectionSpacing) {
                ForEach(vm.layers, id: \.kind) { layer in
                    FocusableLayerCarousel(
                        title: layer.kind.displayName,
                        locked: Binding(
                            get: { vm.layers.first(where: { $0.kind == layer.kind })?.locked ?? false },
                            set: { _ in vm.toggleLock(layer.kind) }
                        ),
                        items: vm.itemsByLayer[layer.kind] ?? [],
                        selectedIndex: Binding(
                            get: { vm.selectedIndex[layer.kind] ?? 0 },
                            set: { vm.select(kind: layer.kind, index: $0) }
                        ),
                        onTapItem: { item in selectedItemForDetail = item },
                        rowHeight: sizing.rowHeight,
                        cardWidth: sizing.cardWidth,
                        emptyBoxHeight: sizing.emptyBoxHeight
                    )
                }

                if vm.layers.isEmpty {
                    Text("No layers selected. Choose a preset below to get started.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 96)
            .animation(.spring(response: 0.28, dampingFraction: 0.92), value: vm.layers.count)
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 8) {
            PresetStrip(selected: $selectedPreset) { newPreset in
                selectedPreset = newPreset
                vm.applyPreset(newPreset)
            }

            HStack(spacing: 12) {
                Button { vm.randomizeUnlocked() } label: {
                    Label("Roll", systemImage: "die.face.5")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)

                Button {
                    Task { await vm.saveOutfit(name: "") }
                } label: {
                    Group {
                        if vm.isSaving { ProgressView().progressViewStyle(.circular) }
                        else { Text("Save").fontWeight(.semibold) }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                .disabled(!vm.isComplete)
                .accessibilityIdentifier("bottomSaveButton")
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text("Manual outfit creation")
                    .font(.custom("SpicyRice-Regular", size: 22, relativeTo: .headline))
                    .minimumScaleFactor(0.8)
            }
            .multilineTextAlignment(.center)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button { showingFilter.toggle() } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }
}

// MARK: - Preset strip

private struct PresetStrip: View {
    @Binding var selected: LayerPreset
    var onChange: (LayerPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LayerPreset.allCases) { preset in
                    Button {
                        guard selected != preset else { return }
                        selected = preset
                        onChange(preset)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: preset.icon)
                            Text(preset.shortTitle).lineLimit(1)
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected == preset ? Color(.systemGray5) : Color(.secondarySystemBackground))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Focusable Layer Carousel
/// Snap-to-center slider. **Selected card stays dead-center** even at edges.
/// Header pin locks the currently centered selection.
private struct FocusableLayerCarousel: View {
    let title: String
    @Binding var locked: Bool

    let items: [WardrobeItem]
    @Binding var selectedIndex: Int
    var onTapItem: (WardrobeItem) -> Void

    let rowHeight: CGFloat
    let cardWidth: CGFloat
    let emptyBoxHeight: CGFloat

    @State private var focusedID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    locked.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: locked ? "pin.fill" : "pin")
                        .foregroundStyle(locked ? .red : .secondary)
                        .padding(6)
                }
                .accessibilityLabel(locked ? "Unlock current selection" : "Lock current selection")
            }

            if items.isEmpty {
                emptyState
            } else {
                slider
            }
        }
        .onAppear { focusedID = selectedIndex }
        .onChange(of: selectedIndex) { newValue in focusedID = newValue }
    }

    // MARK: Slider (dead-center with side insets)
    @ViewBuilder private var slider: some View {
        if #available(iOS 17.0, *) {
            GeometryReader { geo in
                let sideInset = max((geo.size.width - cardWidth) / 2, 0)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Layout.sliderSpacing) {
                            // side spacers let first/last card sit centered
                            Color.clear.frame(width: sideInset)
                            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                                CarouselCard(
                                    urlString: item.imageURL,
                                    isFocused: (focusedID ?? selectedIndex) == i,
                                    height: rowHeight,
                                    width: cardWidth
                                )
                                .id(i)
                                .onTapGesture {
                                    selectedIndex = i
                                    focusedID = i
                                    onTapItem(item)
                                }
                            }
                            Color.clear.frame(width: sideInset)
                        }
                        .scrollTargetLayout()
                    }
                    .frame(height: rowHeight)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $focusedID)
                    .onChange(of: focusedID) { newValue in
                        if let i = newValue, i != selectedIndex {
                            selectedIndex = i
                        }
                    }
                    .onChange(of: selectedIndex) { i in
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(i, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: rowHeight) // keep geo constrained to row
        } else {
            // iOS 16 fallback
            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    ImageOnlyCard(urlString: item.imageURL)
                        .frame(height: rowHeight)
                        .onTapGesture { onTapItem(item) }
                        .tag(i)
                        .padding(.vertical, 2)
                }
            }
            .frame(height: rowHeight)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        }
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: Layout.boxCorner)
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

// MARK: - Image cards

private struct ImageOnlyCard: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let img):
                img.resizable()
                    .scaledToFit()
                    .background(Color(.secondarySystemBackground))
            case .failure(_): Color(.tertiarySystemFill)
            case .empty: ProgressView()
            @unknown default: Color(.tertiarySystemFill)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Layout.boxCorner))
    }
}

private struct CarouselCard: View {
    let urlString: String
    let isFocused: Bool
    let height: CGFloat
    let width: CGFloat

    var body: some View {
        ImageOnlyCard(urlString: urlString)
            .frame(width: width, height: height)
            .scaleEffect(isFocused ? 1.0 : 0.88)
            .opacity(isFocused ? 1.0 : 0.78)
            .shadow(radius: isFocused ? 2 : 0, y: isFocused ? 1 : 0)
            .contentShape(RoundedRectangle(cornerRadius: Layout.boxCorner))
    }
}

#Preview {
    ManualSuggestionView(userId: "demo-user")
}
