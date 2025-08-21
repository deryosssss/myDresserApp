//
//  ItemDetailView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 06/08/2025
//
//  1) Shows the item header (image + favorite + options menu) and a segmented control (About/Outfits/Stats).
//  2) Renders the selected tab's content (about chips, outfits grid, or stats) inside a scroll view.
//  3) Lets you edit fields via sheets, pick a new photo via PhotosPicker, and set "last worn" via a date form.
//  4) Provides actions from a menu (manual outfit, AI outfit, replace photo) and a destructive Delete flow.
//  5) Starts/stops a live outfits listener for this item on appear/disappear.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

private extension String {
    var colorKey: String { trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } // normalized key for color maps
}

struct ItemDetailView: View {
    let item: WardrobeItem                               // item being displayed/edited
    @ObservedObject var wardrobeVM: WardrobeViewModel    // shared VM for data mutations
    var onDelete: () -> Void                             // callback to pop/dismiss after delete

    // Menu & editors
    @State private var showMenu = false                  // options sheet (Create outfit / Replace photo)
    @State private var selectedTab: Tab = .about         // current tab
    @State private var editingField: EditableField?      // which field is being edited (drives EditSheet)
    @State private var showWornPicker = false            // last worn date editor visibility
    @State private var draftWornDate = Date()            // temp date for picker
    @State private var draftText = ""                    // temp text for EditSheet

    // Flows
    @State private var showManualSheet = false           // manual outfit creation sheet
    @State private var showPromptSheet = false           // AI outfit results sheet

    // Replace photo
    @State private var showPhotoPicker = false           // PhotosPicker visibility
    @State private var pickedPhotoItem: PhotosPickerItem? = nil // selected photo
    @State private var isUploading = false               // upload spinner state
    @State private var uploadError: String? = nil        // upload error message (unused here, but set)

    // UI sizes
    private let bubbleSize: CGFloat = 56                 // header action bubble size
    private let iconSize: CGFloat = 22                   // header icon size

    enum Tab: String, CaseIterable { case about = "About", outfits = "Outfits", stats = "Stats" } // segmented tabs

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            // Header image + favorite toggle + options menu
            ItemDetailImageHeader(
                imageURL: item.imageURL,
                isUploading: isUploading,
                bubbleSize: bubbleSize,
                iconSize: iconSize,
                isFavorite: wardrobeVM.isFavorite(item),
                onOptionsTapped: { showMenu.toggle() },
                onFavoriteTapped: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        wardrobeVM.toggleFavorite(item)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            )

            // Segmented control for About/Outfits/Stats
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 20)

            Divider()

            // Main scrollable content per tab
            ScrollView {
                switch selectedTab {
                case .about:
                    // About: chips + inline editors
                    ItemDetailAboutSection(
                        item: item,
                        onEditColours: { draftText = ""; editingField = .colours },
                        onEditSingleField: { field, existing in
                            draftText = existing
                            editingField = field
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical)

                case .outfits:
                    // Outfits: grid of outfits that include this item
                    ItemDetailOutfitsGrid(
                        outfits: wardrobeVM.outfits(for: item),
                        wardrobeVM: wardrobeVM
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                case .stats:
                    // Stats: last worn, count, added date, underused flag
                    ItemDetailStatsSection(
                        lastWornText: lastWornText,
                        outfitCount: wardrobeVM.outfits(for: item).count,
                        addedAtDate: item.addedAt,
                        isUnderused: isUnderused,
                        onEditLastWorn: { showWornPicker = true }
                    )
                    .padding(.horizontal)
                    .padding(.vertical)
                }

                // Destructive delete button
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Text("Delete Item")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
        }
        // Photos picker (opens from menu → "Replace photo")
        .photosPicker(isPresented: $showPhotoPicker,
                      selection: $pickedPhotoItem,
                      matching: .images,
                      preferredItemEncoding: .automatic)
        .onChange(of: pickedPhotoItem) { newItem in       // when user picks a photo → upload
            guard let newItem else { return }
            Task { await replacePhoto(using: newItem) }
        }

        // Sheets for manual outfit, AI prompt, last worn date, and generic field editing
        .sheet(isPresented: $showManualSheet) {
            ManualSuggestionView(userId: item.userId, startPinned: item)
        }
        .sheet(isPresented: $showPromptSheet) {
            PromptResultsSheet(userId: item.userId, initialPrompt: aiSeedPrompt(for: item))
        }
        .sheet(isPresented: $showWornPicker) { lastWornEditor }
        .sheet(item: $editingField) { field in
            EditSheet(
                draftText:          $draftText,
                editingField:       $editingField,
                field:              field,
                singleBindings:     singleBindings,
                listAddBindings:    listAddBindings,
                listRemoveBindings: listRemoveBindings,
                listReadBindings:   listReadBindings
            )
        }

        // Menus & alerts (options dialog + delete confirmation)
        .confirmationDialog("Options", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Create outfit manually") { showManualSheet = true }
            Button("Create outfit with AI")  { showPromptSheet = true }
            Button("Replace photo")          { showPhotoPicker = true }
            Button("Cancel", role: .cancel)  { }
        }
        .alert("Are you sure you want to delete this item?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                wardrobeVM.delete(item)
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        }

        .navigationBarTitleDisplayMode(.inline)           // compact title style
        .onAppear { wardrobeVM.startOutfitsListener(for: item) }   // begin live updates
        .onDisappear { wardrobeVM.stopOutfitsListener(for: item) } // stop when leaving
    }

    // MARK: - Last worn editor
    private var lastWornEditor: some View {
        NavigationStack {
            Form {
                DatePicker("Last Worn", selection: $draftWornDate, displayedComponents: .date) // date-only
            }
            .navigationTitle("Edit Last Worn")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        wardrobeVM.updateItem(item) { $0.lastWorn = draftWornDate } // persist change
                        showWornPicker = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showWornPicker = false }
                }
            }
            .onAppear { draftWornDate = item.lastWorn ?? Date() } // seed with existing date (or today)
        }
    }

    // MARK: - Helpers
    private var lastWornText: String {
        guard let d = item.lastWorn else { return "__/__/__" } // placeholder when unset
        return dateFormatter.string(from: d)
    }

    private var isUnderused: Bool {
        guard let last = item.lastWorn else { return false } // no date → not flagged
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        return days > 90                                      // > 90 days since last worn → underused
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }

    // MARK: - EditSheet bindings
    private var singleBindings: [EditableField: (String) -> Void] {
        [   // single-value fields (write-through closures)
            .category:      { v in wardrobeVM.updateItem(item) { $0.category      = v } },
            .subcategory:   { v in wardrobeVM.updateItem(item) { $0.subcategory   = v } },
            .length:        { v in wardrobeVM.updateItem(item) { $0.length        = v } },
            .style:         { v in wardrobeVM.updateItem(item) { $0.style         = v } },
            .designPattern: { v in wardrobeVM.updateItem(item) { $0.designPattern = v } },
            .closureType:   { v in wardrobeVM.updateItem(item) { $0.closureType   = v } },
            .fit:           { v in wardrobeVM.updateItem(item) { $0.fit           = v } },
            .material:      { v in wardrobeVM.updateItem(item) { $0.material      = v } },
            .dressCode:     { v in wardrobeVM.updateItem(item) { $0.dressCode     = v } },
            .season:        { v in wardrobeVM.updateItem(item) { $0.season        = v } },
            .size:          { v in wardrobeVM.updateItem(item) { $0.size          = v } },
        ]
    }

    private var listAddBindings: [EditableField: (String) -> Void] {
        [   // multi-value fields (append)
            .colours:    { wardrobeVM.modifyList(item, keyPath: \.colours,    add: $0) },
            .customTags: { wardrobeVM.modifyList(item, keyPath: \.customTags, add: $0) },
            .moodTags:   { wardrobeVM.modifyList(item, keyPath: \.moodTags,   add: $0) },
        ]
    }

    private var listRemoveBindings: [EditableField: (String) -> Void] {
        [   // multi-value fields (remove)
            .colours:    { wardrobeVM.modifyList(item, keyPath: \.colours,    remove: $0) },
            .customTags: { wardrobeVM.modifyList(item, keyPath: \.customTags, remove: $0) },
            .moodTags:   { wardrobeVM.modifyList(item, keyPath: \.moodTags,   remove: $0) },
        ]
    }

    private var listReadBindings: [EditableField: () -> [String]] {
        [   // read latest values from VM (avoid stale local copy)
            .colours:    { wardrobeVM.items.first(where: { $0.id == item.id })?.colours    ?? [] },
            .customTags: { wardrobeVM.items.first(where: { $0.id == item.id })?.customTags ?? [] },
            .moodTags:   { wardrobeVM.items.first(where: { $0.id == item.id })?.moodTags   ?? [] },
        ]
    }

    // MARK: - Photo replace & AI seed
    private func replacePhoto(using pickerItem: PhotosPickerItem) async {
        guard !isUploading else { return }                 // throttle duplicate taps
        uploadError = nil
        isUploading = true
        defer {
            isUploading = false
            pickedPhotoItem = nil                          // clear selection after attempt
        }

        do {
            if let data = try await pickerItem.loadTransferable(type: Data.self) { // load bytes from Photos
                let (mime, ext) = ItemDetailHelpers.mimeAndExt(for: pickerItem.supportedContentTypes.first)
                try await wardrobeVM.replacePhotoAsync(item, with: data, contentType: mime, fileExtension: ext)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }
            uploadError = "Couldn’t load selected image."  // fallback error state
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            uploadError = error.localizedDescription       // surface underlying error text (optional UI)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func aiSeedPrompt(for item: WardrobeItem) -> String {
        ItemDetailHelpers.aiSeedPrompt(for: item)          // delegate to helper (includes id if available)
    }

    // Delete alert state (used by .alert above)
    @State private var showDeleteAlert = false
}
