//  ItemDetailView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 06/08/2025.
//
//

import SwiftUI
import FirebaseFirestore

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
            Button("Create outfit manually") { /* TODO */ }
            Button("Create outfit with AI")  { /* TODO */ }
            Button("Replace photo")          { /* TODO */ }
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
                )
                .frame(height: 300)

            HStack {
                // Sandwich: brand yellow bubble, fixed size, thin outline
                Button { showMenu.toggle() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.brandYellow.opacity(0.25))
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                        Image(systemName: "line.horizontal.3")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(.black)
                    }
                    .frame(width: bubbleSize, height: bubbleSize)
                }

                Spacer()

                // Heart: light blue bubble, fixed size, thin outline
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        wardrobeVM.toggleFavorite(item)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                        // animate only the icon, not the bubble size
                        Image(systemName: wardrobeVM.isFavorite(item) ? "heart.fill" : "heart")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(wardrobeVM.isFavorite(item) ? .red : .black)
                            .scaleEffect(wardrobeVM.isFavorite(item) ? 1.15 : 1.0)
                    }
                    .frame(width: bubbleSize, height: bubbleSize)
                }
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
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    // MARK: — Scrollable Content
    private var content: some View {
        Group {
            switch selectedTab {
            case .about:   aboutView
            case .outfits: outfitsView
            case .stats:   statsView
            }
        }
    }

    // MARK: — About Tab
    private var aboutView: some View {
        VStack(spacing: 16) {
            if !item.colours.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Colours")
                        .bold()
                        .padding(.top)
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.colours, id: \.self) { hex in
                                let bg = Color(hex: hex) ?? .gray
                                Text(hex.capitalized)
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(bg)
                                    .foregroundColor(Color.isDark(hex: hex) ? .white : .black)
                                    .cornerRadius(12)
                            }
                            TinyEditButton {
                                draftText = ""
                                editingField = .colours
                            }
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

    // MARK: — Outfits Tab
    private var outfitsView: some View {
        let outs = wardrobeVM.outfits(for: item)
        if outs.isEmpty {
            return AnyView(
                Text("No outfits yet")
                    .foregroundColor(.secondary)
                    .padding()
            )
        } else {
            return AnyView(
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(outs, id: \.id) { outfit in
                            AsyncImage(url: URL(string: outfit.imageURL)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().frame(height: 100)
                                case .success(let img):
                                    img
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 100)
                                        .clipped()
                                default:
                                    Color(.systemGray5)
                                        .frame(height: 100)
                                }
                            }
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
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
            statCard(
                icon: "tshirt",
                title: "Outfits made",
                value: "\(wardrobeVM.outfits(for: item).count)"
            )
            statCard(
                icon: "clock",
                title: "Added",
                value: item.addedAt.map { dateFormatter.string(from: $0) } ?? "__/__/__"
            )
            if isUnderused {
                statCard(icon: "exclamationmark.triangle",
                         title: "Underused",
                         value: "Not worn >90d")
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
}
