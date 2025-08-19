//  ItemDetailView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 06/08/2025.
//

import SwiftUI
import UIKit
import FirebaseFirestore
import PhotosUI
import UniformTypeIdentifiers

/// Detail screen for a single wardrobe item:
/// - Shows the item image with quick actions (menu, favorite)
/// - Segmented tabs: About / Outfits / Stats
/// - Inline “chip” editors that launch a polymorphic EditSheet
/// - Last-worn date editor
/// - Delete item
/// - Extras:
///   - Replace photo from Camera Roll (PhotosPicker + Firebase Storage upload)
///   - Create outfit manually => opens ManualSuggestionView with this item pre-selected & locked
///   - Create outfit with AI => opens PromptResultsView seeded to include this exact item
private extension String {
    var colorKey: String { trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
}

struct ItemDetailView: View {
    let item: WardrobeItem
    @ObservedObject var wardrobeVM: WardrobeViewModel
    var onDelete: () -> Void

    @State private var showMenu = false
    @State private var selectedTab: Tab = .about
    @State private var editingField: EditableField?
    @State private var showWornPicker = false
    @State private var draftWornDate = Date()
    @State private var draftText = ""
    @State private var showDeleteAlert = false

    // Flows
    @State private var showManualSheet = false
    @State private var showPromptSheet = false
    @State private var showPhotoPicker = false
    @State private var pickedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    @State private var uploadError: String? = nil

    // unified sizes
    private let bubbleSize: CGFloat = 56
    private let iconSize: CGFloat = 22

    enum Tab: String, CaseIterable {
        case about   = "About"
        case outfits = "Outfits"
        case stats   = "Stats"
    }

    var body: some View {
        VStack(spacing: 0) {
            imageSection

            tabPicker
            Divider()
            ScrollView {
                content
                    .padding(.horizontal)
                deleteButton
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
        }
        // Replace photo (camera roll)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickedPhotoItem,
            matching: .images,
            preferredItemEncoding: .automatic
        )
        .onChange(of: pickedPhotoItem) { newItem in
            guard let newItem else { return }
            Task { await replacePhoto(using: newItem) }
        }

        // Manual outfit creator with this item locked
        .sheet(isPresented: $showManualSheet) {
            ManualSuggestionView(userId: item.userId, startPinned: item)
        }

        // AI outfit with THIS exact item included (seed via ID in initialPrompt)
        .sheet(isPresented: $showPromptSheet) {
            PromptResultsSheet(
                userId: item.userId,
                initialPrompt: aiSeedPrompt(for: item)
            )
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { wardrobeVM.startOutfitsListener(for: item) }
        .onDisappear { wardrobeVM.stopOutfitsListener(for: item) }
    }

    // MARK: — Top Image + Controls
    private var imageSection: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .overlay(
                    AsyncImage(url: URL(string: item.imageURL)) { ph in
                        switch ph {
                        case .empty:    ProgressView()
                        case .success(let img):
                            img.resizable().scaledToFit()
                        default:        Color.white
                        }
                    }
                    .overlay {
                        if isUploading {
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                VStack(spacing: 10) {
                                    ProgressView()
                                    Text("Updating photo…")
                                        .font(.footnote)
                                }
                            }
                        }
                    }
                )
                .frame(height: 300)
                .animation(.default, value: isUploading)

            HStack {
                // Options button
                Button { showMenu.toggle() } label: {
                    ZStack {
                        Circle().fill(Color.brandYellow.opacity(0.25))
                        Circle().stroke(Color.black, lineWidth: 1)
                        Image(systemName: "line.horizontal.3")
                            .resizable().scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(.black)
                    }
                    .frame(width: bubbleSize, height: bubbleSize)
                }
                .disabled(isUploading)
                .accessibilityIdentifier("itemOptionsButton")

                Spacer()

                // Favorite button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        wardrobeVM.toggleFavorite(item)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                } label: {
                    let isFav = wardrobeVM.isFavorite(item)
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.15))
                        Circle().stroke(Color.black, lineWidth: 1)
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .resizable().scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(isFav ? .red : .black)
                            .scaleEffect(isFav ? 1.12 : 1.0)
                    }
                    .frame(width: bubbleSize, height: bubbleSize)
                }
                .disabled(isUploading)
                .accessibilityIdentifier("favoriteButton")
            }
            .padding(.horizontal, 24)
            .offset(y: -24)
        }
        .background(Color.white)
    }

    // MARK: — Tab Picker
    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    // MARK: — Scrollable Content
    private var content: some View {
        Group {
            switch selectedTab {
            case .about:   aboutView
            case .outfits: outfitsView   // 👈 collage grid here
            case .stats:   statsView
            }
        }
    }

    // MARK: — About Tab
    private var aboutView: some View {
        VStack(spacing: 16) {
            if !item.colours.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Colours").bold()
                        .padding(.top).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.colours, id: \.self) { name in
                                let key = name.colorKey
                                let resolvedHex = item.colorHexByName[key] ?? name
                                let bg = Color(hex: resolvedHex) ?? .gray

                                Text(name.capitalized)
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(bg)
                                    .foregroundColor(Color.isDark(hex: resolvedHex) ? .white : .black)
                                    .cornerRadius(12)
                            }
                            TinyEditButton { draftText = ""; editingField = .colours }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            chipRow("Category",      item.category,      .category)
            chipRow("Sub-Category",  item.subcategory,   .subcategory)
            chipRow("Length",        item.length,        .length)
            chipRow("Style",         item.style,         .style)
            chipRow("Pattern",       item.designPattern, .designPattern)
            chipRow("Closure",       item.closureType,   .closureType)
            chipRow("Fit",           item.fit,           .fit)
            chipRow("Material",      item.material,      .material)

            chipSection("Custom Tags", item.customTags, .customTags)
            chipRow("Dress Code",     item.dressCode,    .dressCode)
            chipRow("Season",         item.season,       .season)
            chipRow("Size",           item.size,         .size)
            chipSection("Mood Tags",  item.moodTags,     .moodTags)
        }
        .padding(.vertical)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // MARK: — Outfits Tab (collage grid with stable IDs)
    private struct OutfitRow: Identifiable {
        let id: String
        let outfit: Outfit
    }

    private var outfitsForItemRows: [OutfitRow] {
        let outs = wardrobeVM.outfits(for: item)
        return outs.enumerated().map { idx, o in
            OutfitRow(id: o.id ?? "local-\(idx)-\(o.imageURL)", outfit: o)
        }
    }

    private var outfitsView: some View {
        if outfitsForItemRows.isEmpty {
            return AnyView(
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No outfits yet")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            )
        } else {
            return AnyView(
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(outfitsForItemRows) { row in
                        NavigationLink {
                            OutfitDetailView(outfit: row.outfit)
                                .environmentObject(wardrobeVM)   // ✅ needed by detail
                        } label: {
                            OutfitCollageCard(outfit: row.outfit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            )
        }
    }

    // MARK: — Stats Tab
    private var statsView: some View {
        VStack(spacing: 12) {
            HStack {
                statCard(icon: "calendar", title: "Last worn", value: lastWornText)
                TinyEditButton { showWornPicker = true }
            }
            statCard(icon: "tshirt", title: "Outfits made",
                     value: "\(wardrobeVM.outfits(for: item).count)")
            statCard(icon: "clock", title: "Added",
                     value: item.addedAt.map { dateFormatter.string(from: $0) } ?? "__/__/__")
            if isUnderused {
                statCard(icon: "exclamationmark.triangle",
                         title: "Underused", value: "Not worn >90d")
                    .background(Color.brandYellow)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical)
    }

    // MARK: — Delete Button
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            Text("Delete Item")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
        }
        .padding(.horizontal, 20)
    }

    // MARK: — Last Worn Editor
    private var lastWornEditor: some View {
        NavigationStack {
            Form {
                DatePicker("Last Worn", selection: $draftWornDate, displayedComponents: .date)
            }
            .navigationTitle("Edit Last Worn")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        wardrobeVM.updateItem(item) { $0.lastWorn = draftWornDate }
                        showWornPicker = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showWornPicker = false }
                }
            }
            .onAppear { draftWornDate = item.lastWorn ?? Date() }
        }
    }

    // MARK: — Helpers
    private func chipRow(_ title: String, _ text: String, _ field: EditableField) -> some View {
        ChipRowView(title: title, text: text) {
            draftText = text
            editingField = field
        }
    }
    private func chipSection(_ title: String, _ chips: [String], _ field: EditableField) -> some View {
        ChipSectionView(title: title, chips: chips) {
            draftText = ""
            editingField = field
        }
    }
    private func statCard(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: — Computed
    private var lastWornText: String {
        guard let d = item.lastWorn else { return "__/__/__" }
        return dateFormatter.string(from: d)
    }
    private var isUnderused: Bool {
        guard let last = item.lastWorn else { return false }
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        return days > 90
    }
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }

    // MARK: — Bindings for EditSheet
    private var singleBindings: [EditableField: (String) -> Void] {
        [
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
        [
            .colours:    { wardrobeVM.modifyList(item, keyPath: \.colours,    add: $0) },
            .customTags: { wardrobeVM.modifyList(item, keyPath: \.customTags, add: $0) },
            .moodTags:   { wardrobeVM.modifyList(item, keyPath: \.moodTags,   add: $0) },
        ]
    }
    private var listRemoveBindings: [EditableField: (String) -> Void] {
        [
            .colours:    { wardrobeVM.modifyList(item, keyPath: \.colours,    remove: $0) },
            .customTags: { wardrobeVM.modifyList(item, keyPath: \.customTags, remove: $0) },
            .moodTags:   { wardrobeVM.modifyList(item, keyPath: \.moodTags,   remove: $0) },
        ]
    }
    private var listReadBindings: [EditableField: () -> [String]] {
        [
            .colours:    { wardrobeVM.items.first(where: { $0.id == item.id })?.colours    ?? [] },
            .customTags: { wardrobeVM.items.first(where: { $0.id == item.id })?.customTags ?? [] },
            .moodTags:   { wardrobeVM.items.first(where: { $0.id == item.id })?.moodTags   ?? [] },
        ]
    }

    // MARK: — Replace photo flow (Data-only; UIImage is not Transferable)
    private func mimeAndExt(for utType: UTType?) -> (mime: String, ext: String) {
        guard let t = utType else { return ("image/jpeg", "jpg") }
        if t.conforms(to: .png)  { return ("image/png",  "png") }
        if t.conforms(to: .heic) { return ("image/heic", "heic") }
        if t.conforms(to: .heif) { return ("image/heif", "heif") }
        return ("image/jpeg", "jpg")
    }

    private func replacePhoto(using pickerItem: PhotosPickerItem) async {
        guard !isUploading else { return }
        uploadError = nil
        isUploading = true
        defer {
            isUploading = false
            pickedPhotoItem = nil
        }

        do {
            if let data = try await pickerItem.loadTransferable(type: Data.self) {
                let (mime, ext) = mimeAndExt(for: pickerItem.supportedContentTypes.first)
                try await wardrobeVM.replacePhotoAsync(
                    item,
                    with: data,
                    contentType: mime,
                    fileExtension: ext
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }

            uploadError = "Couldn’t load selected image."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            uploadError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: — AI seed (ensures outfits for THIS item)
    private func aiSeedPrompt(for item: WardrobeItem) -> String {
        let label = [item.category, item.subcategory]
            .joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if let id = item.id {
            return "Create outfit ideas that MUST include wardrobe item ID \(id). Item: \(label)."
        } else {
            return "Create outfit ideas built around this item: \(label)."
        }
    }
}

// MARK: - Wrapper sheet for PromptResultsView with a Close button
private struct PromptResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    let initialPrompt: String

    var body: some View {
        NavigationStack {
            PromptResultsView(userId: userId, initialPrompt: initialPrompt)
                .navigationTitle("Your Outfit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: — Outfit collage card (supports up to 6 tiles)

private struct OutfitCollageCard: View {
    let outfit: Outfit

    var body: some View {
        ZStack(alignment: .topTrailing) {
            OutfitCollageView(urls: outfit.itemImageURLs)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

            if outfit.isFavorite {
                Image(systemName: "heart.fill")
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(6)
            }
        }
    }
}

private struct OutfitCollageView: View {
    let urls: [String]

    private func tile(_ url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty: Color(.secondarySystemBackground)
            case .success(let img): img.resizable().scaledToFit()
            default: Color(.tertiarySystemFill)
            }
        }
        .clipped()
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s: CGFloat = 2

            // 2-col metrics
            let col2W = (w - s) / 2
            let row2H = (h - s) / 2

            // 3-col metrics (used for 3, 5, 6)
            let col3W = (w - 2*s) / 3
            let row3H = (h - s) / 2

            ZStack {
                switch min(urls.count, 6) {
                case 0:
                    Color(.secondarySystemBackground)

                case 1:
                    tile(urls[0]).frame(width: w, height: h)

                case 2:
                    HStack(spacing: s) {
                        tile(urls[0]).frame(width: col2W, height: h)
                        tile(urls[1]).frame(width: col2W, height: h)
                    }

                case 3:
                    HStack(spacing: s) {
                        tile(urls[0]).frame(width: col3W, height: h)
                        tile(urls[1]).frame(width: col3W, height: h)
                        tile(urls[2]).frame(width: col3W, height: h)
                    }

                case 4:
                    VStack(spacing: s) {
                        HStack(spacing: s) {
                            tile(urls[0]).frame(width: col2W, height: row2H)
                            tile(urls[1]).frame(width: col2W, height: row2H)
                        }
                        HStack(spacing: s) {
                            tile(urls[2]).frame(width: col2W, height: row2H)
                            tile(urls[3]).frame(width: col2W, height: row2H)
                        }
                    }

                case 5, 6:
                    VStack(spacing: s) {
                        HStack(spacing: s) {
                            tile(urls[0]).frame(width: col3W, height: row3H)
                            tile(urls[1]).frame(width: col3W, height: row3H)
                            tile(urls[2]).frame(width: col3W, height: row3H)
                        }
                        HStack(spacing: s) {
                            tile(urls[3]).frame(width: col3W, height: row3H)
                            tile(urls[4]).frame(width: col3W, height: row3H)
                            if urls.count >= 6 {
                                tile(urls[5]).frame(width: col3W, height: row3H)
                            } else {
                                Color(.secondarySystemBackground)
                                    .frame(width: col3W, height: row3H)
                            }
                        }
                    }

                default:
                    EmptyView()
                }
            }
        }
    }
}
