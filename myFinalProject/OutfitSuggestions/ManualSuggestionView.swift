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
    static let buttonHeight: CGFloat = 20
    static let sliderSpacing: CGFloat = 14   // horizontal spacing between cards
}

/// Computed sizing based on how many layers are shown
private struct AdaptiveSize {
    let rowHeight: CGFloat
    let cardWidth: CGFloat
    let sectionSpacing: CGFloat     // tighter vertical spacing between layers
    let emptyBoxHeight: CGFloat

    static func forLayers(_ count: Int) -> AdaptiveSize {
        switch count {
        case ...1: return .init(rowHeight: 240, cardWidth: 190, sectionSpacing: 12, emptyBoxHeight: 210)
        case 2:    return .init(rowHeight: 210, cardWidth: 170, sectionSpacing: 10, emptyBoxHeight: 185)
        case 3:    return .init(rowHeight: 165, cardWidth: 138, sectionSpacing: 8,  emptyBoxHeight: 150)
        case 4:    return .init(rowHeight: 116, cardWidth: 106, sectionSpacing: 6,  emptyBoxHeight: 104)
        case 5:    return .init(rowHeight: 116, cardWidth: 106, sectionSpacing: 6,  emptyBoxHeight: 104)
        case 6:    return .init(rowHeight: 108, cardWidth: 98,  sectionSpacing: 5,  emptyBoxHeight: 96)
        default:   return .init(rowHeight: 100, cardWidth: 92,  sectionSpacing: 5,  emptyBoxHeight: 90)
        }
    }
}

struct ManualSuggestionView: View {
    @StateObject private var vm: ManualSuggestionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: LayerPreset
    @State private var selectedItemForDetail: WardrobeItem?
    @State private var showingPreview = false

    /// start with a specific item pinned & locked (optional)
    private let startPinned: WardrobeItem?

    init(userId: String, startPinned: WardrobeItem? = nil) {
        let preset: LayerPreset = .three_TopBottomShoes
        _vm = StateObject(wrappedValue: ManualSuggestionViewModel(userId: userId, preset: preset.kinds))
        _selectedPreset = State(initialValue: preset)
        self.startPinned = startPinned
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
            .task {
                await vm.loadAll()
                await applyStartPinnedIfNeeded()
            }
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
            .sheet(isPresented: $showingPreview) {
                OutfitPreviewSheet(
                    items: vm.selectedItems(),
                    onClose: { showingPreview = false },
                    onSave: { name, occasion, date, description, isFav in
                        Task {
                            await vm.saveOutfit(
                                name: name,
                                occasion: occasion,
                                description: description,
                                date: date,
                                isFavorite: isFav,
                                tags: []
                            )
                            showingPreview = false
                        }
                    }
                )
            }
        }
    }

    // MARK: - Content
    private var content: some View {
        // Display tweak: show Outerwear first if present (view-only ordering)
        let displayLayers: [LayerSelection] = {
            let out = vm.layers.filter { $0.kind == .outerwear }
            let others = vm.layers.filter { $0.kind != .outerwear }
            return out + others
        }()

        return VStack(alignment: .leading, spacing: sizing.sectionSpacing) {
            VStack(spacing: sizing.sectionSpacing) {
                ForEach(displayLayers, id: \.kind) { layer in
                    FocusableLayerCarousel(
                        title: layer.kind.displayName,
                        locked: Binding(
                            get: { vm.layers.first(where: { $0.kind == layer.kind })?.locked ?? false },
                            set: { isLocked in
                                if isLocked != (vm.layers.first(where: { $0.kind == layer.kind })?.locked ?? false) {
                                    vm.toggleLock(layer.kind)
                                }
                            }
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
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 88)
            .animation(.spring(response: 0.28, dampingFraction: 0.92), value: vm.layers.count)
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 6) {
            PresetStrip(selected: $selectedPreset) { newPreset in
                selectedPreset = newPreset
                vm.applyPreset(newPreset)
            }

            HStack(spacing: 10) {
                Button { vm.randomizeUnlocked() } label: {
                    Label("Roll", systemImage: "die.face.5")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)

                Button { showingPreview = true } label: {
                    Text("Preview")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
                .disabled(!vm.isComplete || vm.selectedItems().isEmpty)
                .accessibilityIdentifier("bottomSaveButton")
            }
            .padding(.horizontal)
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text("Manual outfit creation")
                    .font(.custom("SpicyRice-Regular", size: 20, relativeTo: .headline))
                    .minimumScaleFactor(0.8)
            }
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Start pinned helper (kept inside the View)
    private func applyStartPinnedIfNeeded() async {
        guard let item = startPinned else { return }
        guard let kind = inferKind(for: item) else { return }

        // Ensure preset includes the layer with the pinned item
        if !vm.layers.map(\.kind).contains(kind) {
            // Choose the smallest preset that contains the kind
            let candidate = LayerPreset.allCases
                .sorted { $0.kinds.count < $1.kinds.count }
                .first(where: { $0.kinds.contains(kind) })
                ?? (kind == .dress ? .two_DressShoes : .three_TopBottomShoes)
            selectedPreset = candidate
            vm.applyPreset(candidate)
            // allow model to refresh items
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        // Select the exact item in its layer (by id) and lock it
        guard let arr = vm.itemsByLayer[kind], let id = item.id,
              let idx = arr.firstIndex(where: { $0.id == id }) ?? arr.firstIndex(where: { $0.imageURL == item.imageURL }) else { return }
        vm.select(kind: kind, index: idx)
        vm.toggleLock(kind)
    }

    /// Minimal heuristic mirroring your Store.matches() for seeding
    private func inferKind(for item: WardrobeItem) -> LayerKind? {
        let c = item.category.lowercased()
        let s = item.subcategory.lowercased()
        let joined = "\(c) \(s)"

        func has(_ terms: [String]) -> Bool { terms.contains { joined.contains($0) } }

        if has(["dress","gown","jumpsuit","overall"]) { return .dress }
        if has(["jacket","coat","blazer","outerwear","parka"]) { return .outerwear }
        if has(["pant","pants","trouser","trousers","jeans","skirt","short","leggings"]) { return .bottom }
        if has(["shoe","shoes","sneaker","trainer","boot","boots","sandal","loafer","heel","footwear"]) { return .shoes }
        if has(["bag","handbag","backpack","tote","crossbody","purse","wallet"]) { return .bag }
        if has(["belt","scarf","hat","cap","jewellery","jewelry","glove","accessory"]) { return .accessory }
        return .top
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

// MARK: - Focusable Layer
/// Pin button locks the *featured (centered)* card.
/// While locked, scroll + taps are disabled and focus is kept on that card.
private struct FocusableLayerCarousel: View {
    let title: String
    @Binding var locked: Bool

    let items: [WardrobeItem]
    @Binding var selectedIndex: Int
    var onTapItem: (WardrobeItem) -> Void

    let rowHeight: CGFloat
    let cardWidth: CGFloat
    let emptyBoxHeight: CGFloat

    @State private var focusedID: Int?      // bound to the centered card (iOS 17 path)
    @State private var lockedAtIndex: Int?  // the index captured when lock engages

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Button {
                    // Lock whatever is featured right now (centered if available; else selectedIndex)
                    let featured = (focusedID ?? selectedIndex)
                    let willLock = !locked
                    locked = willLock
                    if willLock {
                        lockedAtIndex = featured
                        withAnimation(.easeInOut) {
                            focusedID = featured
                            selectedIndex = featured
                        }
                    } else {
                        lockedAtIndex = nil
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: locked ? "pin.fill" : "pin")
                        .foregroundStyle(locked ? .red : .secondary)
                        .padding(4)
                }
                .accessibilityLabel(locked ? "Unlock current selection" : "Lock current featured item")
                .accessibilityIdentifier("pinButton_\(title)")
            }

            if items.isEmpty {
                emptyState
            } else {
                slider
                    .overlay(centerGuide)
                    .mask(edgeFades)
            }
        }
        .onAppear { focusedID = selectedIndex }

        // Keep VM selection synced to the featured card while **unlocked** (user scrolls).
        .onChange(of: focusedID) { newValue in
            guard !locked else {
                // If locked and momentum changed focus, snap back to the pinned index.
                if let pinned = lockedAtIndex, newValue != pinned {
                    withAnimation(.easeInOut) { focusedID = pinned }
                }
                return
            }
            if let idx = newValue, idx != selectedIndex {
                selectedIndex = idx
            }
        }

        // When VM changes selection programmatically (e.g., Roll), move the carousel to match.
        .onChange(of: selectedIndex) { newValue in
            guard !locked else { return }
            withAnimation(.easeInOut) { focusedID = newValue }
        }

        // Keep a valid focus if items change while locked.
        .onChange(of: items.count) { _ in
            guard locked else { return }
            if let idx = lockedAtIndex, !items.indices.contains(idx) {
                let clamped = max(0, min(idx, items.count - 1))
                lockedAtIndex = clamped
                withAnimation(.easeInOut) {
                    focusedID = clamped
                    selectedIndex = clamped
                }
            }
        }
        // If lock is toggled externally (e.g., startPinned flow), sync our local state
        .onChange(of: locked) { isLocked in
            if isLocked {
                lockedAtIndex = selectedIndex
                focusedID = selectedIndex
            } else {
                lockedAtIndex = nil
            }
        }
    }

    // MARK: Slider
    @ViewBuilder private var slider: some View {
        if #available(iOS 17.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Layout.sliderSpacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        CarouselCard(
                            urlString: item.imageURL,
                            isFocused: (focusedID ?? selectedIndex) == i,
                            height: rowHeight,
                            width: cardWidth
                        )
                        .id(i)
                        .onTapGesture {
                            guard !locked else { return }
                            selectedIndex = i
                            focusedID = i
                            onTapItem(item)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: rowHeight)
            .contentMargins(.horizontal, (UIScreen.main.bounds.width - cardWidth)/2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID)
            .allowsHitTesting(!locked)
            .scrollDisabled(locked)
        } else {
            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    ImageOnlyCard(urlString: item.imageURL)
                        .frame(height: rowHeight)
                        .onTapGesture { guard !locked else { return }; onTapItem(item) }
                        .tag(i)
                        .padding(.vertical, 2)
                }
            }
            .frame(height: rowHeight)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .allowsHitTesting(!locked)
        }
    }

    private var centerGuide: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(width: 1)
            .allowsHitTesting(false)
    }

    private var edgeFades: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black,  location: 0.08),
                .init(color: .black,  location: 0.92),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: rowHeight)
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
            .scaleEffect(isFocused ? 1.0 : 0.9)
            .opacity(isFocused ? 1.0 : 0.78)
            .shadow(radius: isFocused ? 2 : 0, y: isFocused ? 1 : 0)
            .contentShape(RoundedRectangle(cornerRadius: Layout.boxCorner))
            .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}
