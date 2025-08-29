//
//  ManualSuggestionView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//
/// Screen to manually assemble an outfit by scrolling per-layer carousels
/// (Top/Bottom/Shoes/etc). Pairs tightly with `ManualSuggestionViewModel`.
/// Key ideas:
/// • View owns only UI state; all wardrobe logic lives in the VM.
/// • Layers are driven by a preset (e.g. Top+Bottom+Shoes) and can be re-applied.
/// • Each layer uses a focusable carousel with an optional “pin/lock”.
/// • A preview sheet lets the user save the composed outfit.
//

import SwiftUI

struct ManualSuggestionView: View {
    // VM is @StateObject so it is created once per screen instance (stable across view reloads).
    @StateObject private var vm: ManualSuggestionViewModel
    @Environment(\.dismiss) private var dismiss

    // Local UI state (purely view concerns)
    @State private var selectedPreset: LayerPreset
    @State private var selectedItemForDetail: WardrobeItem?
    @State private var showingPreview = false

    /// Optional: start with a specific item pre-selected & locked in its layer.
    private let startPinned: WardrobeItem?

    /// Custom init lets us seed the VM with a default preset and pass `startPinned`.
    init(userId: String, startPinned: WardrobeItem? = nil) {
        let preset: LayerPreset = .three_TopBottomShoes
        _vm = StateObject(wrappedValue: ManualSuggestionViewModel(userId: userId, preset: preset.kinds))
        _selectedPreset = State(initialValue: preset)
        self.startPinned = startPinned
    }

    /// Layout tokens computed from current layer count (keeps UI compact when many rows).
    private var sizing: ManualAdaptiveSize { ManualAdaptiveSize.forLayers(vm.layers.count) }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    content
                        .padding(.top, ManualLayout.topPadding)
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

            // Item details (opened when user taps a card). On delete → reload items.
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

    // MARK: - Content (list of per-layer carousels)
    private var content: some View {
        let displayLayers: [LayerSelection] = {
            let out = vm.layers.filter { $0.kind == .outerwear }
            let others = vm.layers.filter { $0.kind != .outerwear }
            return out + others
        }()

        return VStack(alignment: .leading, spacing: sizing.sectionSpacing) {
            VStack(spacing: sizing.sectionSpacing) {
                ForEach(displayLayers, id: \.kind) { layer in
                    // For each logical layer, render a carousel bound to VM state.
                    FocusableLayerCarousel(
                        title: layer.kind.displayName,
                        // Lock binding toggles VM's stored `locked` for that kind.
                        locked: Binding(
                            get: { vm.layers.first(where: { $0.kind == layer.kind })?.locked ?? false },
                            set: { isLocked in
                                // Only forward the toggle if it truly changed (avoids feedback loops).
                                if isLocked != (vm.layers.first(where: { $0.kind == layer.kind })?.locked ?? false) {
                                    vm.toggleLock(layer.kind)
                                }
                            }
                        ),
                        // Items to display for this layer.
                        items: vm.itemsByLayer[layer.kind] ?? [],
                        // Selected index for this layer → drives which item is “chosen”.
                        selectedIndex: Binding(
                            get: { vm.selectedIndex[layer.kind] ?? 0 },
                            set: { vm.select(kind: layer.kind, index: $0) }
                        ),
                        // Tap → open detail sheet
                        onTapItem: { item in selectedItemForDetail = item },
                        // Adaptive sizing keeps rows readable across different presets.
                        rowHeight: sizing.rowHeight,
                        cardWidth: sizing.cardWidth,
                        emptyBoxHeight: sizing.emptyBoxHeight
                    )
                }

                // Friendly hint when no preset/layers are active.
                if vm.layers.isEmpty {
                    Text("No layers selected. Choose a preset below to get started.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 88) // leave room for bottom action bar
            .animation(.spring(response: 0.28, dampingFraction: 0.92), value: vm.layers.count)
        }
    }

    // MARK: - Bottom Bar (preset pills + actions)
    private var bottomBar: some View {
        VStack(spacing: 6) {
            // Horizontal preset pills. Selecting reconfigures `vm.layers` & resets selections.
            PresetStrip(selected: $selectedPreset) { newPreset in
                selectedPreset = newPreset
                vm.applyPreset(newPreset)
            }

            HStack(spacing: 10) {
                // “Roll” randomizes only the UNLOCKED layers (keeps pinned picks intact).
                Button { vm.randomizeUnlocked() } label: {
                    Label("Roll", systemImage: "die.face.5")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: ManualLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)

                // Preview becomes enabled when all required layers are selected.
                Button { showingPreview = true } label: {
                    Text("Preview")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: ManualLayout.buttonHeight)
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
        .background(.ultraThinMaterial) // translucent blur so content remains visible behind
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

    // MARK: - Start-pinned flow
    /// If a `startPinned` item was provided:
    /// • ensure the current preset contains that layer,
    /// • find the item in its layer’s source array,
    /// • select + lock it so rolling won’t change it.
    private func applyStartPinnedIfNeeded() async {
        guard let item = startPinned else { return }
        guard let kind = ItemKindInference.inferKind(for: item) else { return }

        // If current preset doesn’t include the needed kind, switch to the smallest that does.
        if !vm.layers.map(\.kind).contains(kind) {
            let candidate = LayerPreset.allCases
                .sorted { $0.kinds.count < $1.kinds.count }
                .first(where: { $0.kinds.contains(kind) })
                ?? (kind == .dress ? .two_DressShoes : .three_TopBottomShoes)
            selectedPreset = candidate
            vm.applyPreset(candidate)

            // Let the VM refresh `itemsByLayer` before selecting (light delay instead of chaining).
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        // Select by id (fallback to imageURL) and then lock that layer.
        guard let arr = vm.itemsByLayer[kind], let id = item.id,
              let idx = arr.firstIndex(where: { $0.id == id }) ?? arr.firstIndex(where: { $0.imageURL == item.imageURL }) else { return }
        vm.select(kind: kind, index: idx)
        vm.toggleLock(kind)
    }
}
