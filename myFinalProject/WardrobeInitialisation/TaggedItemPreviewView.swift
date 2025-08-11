//  TaggedItemPreviewView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import SwiftUI
import UIKit

// MARK: - Color Helpers

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(
            red:   Double((v >> 16) & 0xFF)/255,
            green: Double((v >>  8) & 0xFF)/255,
            blue:  Double((v >>  0) & 0xFF)/255
        )
    }
    static func isDark(hex: String) -> Bool {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return false }
        let r = Double((v >> 16) & 0xFF)
        let g = Double((v >>  8) & 0xFF)
        let b = Double((v >>  0) & 0xFF)
        let lum = (0.299*r + 0.587*g + 0.114*b)/255
        return lum < 0.5
    }
}

struct TaggedItemPreviewView: View {
    let originalImage: UIImage
    @ObservedObject var taggingVM: ImageTaggingViewModel
    var onDismiss: () -> Void

    @State private var editingField: EditableField?
    @State private var draftText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Review & Save")
                    .font(AppFont.spicyRice(size: 28))
                    .padding(.top)

                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .background(Color(white: 0.93))
                    .cornerRadius(12)
                    .padding(.horizontal)

                if let cols = taggingVM.deepTags?.colors, !cols.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Colours").bold().padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(cols, id: \.hex_code) { c in
                                    let bg = Color(hex: c.hex_code) ?? .gray
                                    Text(c.name.capitalized)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(bg)
                                        .foregroundColor(Color.isDark(hex: c.hex_code) ? .white : .black)
                                        .cornerRadius(12)
                                }
                                TinyEditButton { startEditing(.colours) }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                ChipRowView(title: "Category",      text: taggingVM.category)     { startEditing(.category) }
                ChipRowView(title: "Sub Category",  text: taggingVM.subcategory)  { startEditing(.subcategory) }
                ChipRowView(title: "Length",        text: taggingVM.length)       { startEditing(.length) }
                ChipRowView(title: "Style",         text: taggingVM.style)        { startEditing(.style) }
                ChipRowView(title: "Design / Pattern", text: taggingVM.designPattern) { startEditing(.designPattern) }
                ChipRowView(title: "Closure",       text: taggingVM.closureType)  { startEditing(.closureType) }
                ChipRowView(title: "Fit",           text: taggingVM.fit)          { startEditing(.fit) }
                ChipRowView(title: "Material",      text: taggingVM.material)     { startEditing(.material) }

                ChipSectionView(title: "Custom Tags", chips: taggingVM.tags) { startEditing(.customTags) }
                ChipRowView(title: "Dress Code",     text: taggingVM.dressCode)   { startEditing(.dressCode) }
                ChipRowView(title: "Season",         text: taggingVM.season)      { startEditing(.season) }
                ChipRowView(title: "Size",           text: taggingVM.size)        { startEditing(.size) }
                ChipSectionView(title: "Mood Tags",  chips: taggingVM.moodTags)   { startEditing(.moodTags) }

                // MARK: — NEW: Small section for Source / Gender / Favorite (minimal UI change)
                VStack(alignment: .leading, spacing: 8) {
                    Text("More").bold().padding(.horizontal)

                    // Source type
                    HStack {
                        Text("Source").font(.subheadline)
                        Spacer()
                        Picker("", selection: $taggingVM.sourceType) {
                            Text("Camera").tag(WardrobeItem.SourceType.camera)
                            Text("Gallery").tag(WardrobeItem.SourceType.gallery)
                            Text("Web").tag(WardrobeItem.SourceType.web)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                    }
                    .padding(.horizontal)

                    // Gender
                    HStack {
                        Text("Gender").font(.subheadline)
                        Spacer()
                        Picker("", selection: $taggingVM.gender) {
                            Text("Woman").tag("Woman")
                            Text("Man").tag("Man")
                            Text("Unisex").tag("Unisex")
                            Text("Other").tag("Other")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)
                    }
                    .padding(.horizontal)

                    // Favorite toggle
                    Toggle(isOn: $taggingVM.isFavorite) {
                        Text("Mark as Favorite")
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 4)

                HStack(spacing: 12) {
                    Button("Delete") {
                        taggingVM.clearAll()
                        onDismiss()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandPink)
                    .foregroundColor(.black)
                    .cornerRadius(8)

                    Button("Save") {
                        taggingVM.uploadAndSave(image: originalImage)
                        onDismiss()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandGreen)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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
    }

    // MARK: - Bindings & Editing

    private func startEditing(_ field: EditableField) {
        switch field {
        case .colours, .customTags, .moodTags:
            draftText = ""
        case .category:    draftText = taggingVM.category
        case .subcategory: draftText = taggingVM.subcategory
        case .length:      draftText = taggingVM.length
        case .style:       draftText = taggingVM.style
        case .designPattern: draftText = taggingVM.designPattern
        case .closureType: draftText = taggingVM.closureType
        case .fit:         draftText = taggingVM.fit
        case .material:    draftText = taggingVM.material
        case .dressCode:   draftText = taggingVM.dressCode
        case .season:      draftText = taggingVM.season
        case .size:        draftText = taggingVM.size
        default:           draftText = ""
        }
        editingField = field
    }

    private var singleBindings: [EditableField: (String) -> Void] {
        [
            .category:      { taggingVM.category      = $0 },
            .subcategory:   { taggingVM.subcategory   = $0 },
            .length:        { taggingVM.length        = $0 },
            .style:         { taggingVM.style         = $0 },
            .designPattern: { taggingVM.designPattern = $0 },
            .closureType:   { taggingVM.closureType   = $0 },
            .fit:           { taggingVM.fit           = $0 },
            .material:      { taggingVM.material      = $0 },
            .dressCode:     { taggingVM.dressCode     = $0 },
            .season:        { taggingVM.season        = $0 },
            .size:          { taggingVM.size          = $0 },
        ]
    }

    private var listAddBindings: [EditableField: (String) -> Void] {
        [
            .colours:    { taggingVM.colours.append($0) },
            .customTags: { taggingVM.tags.append($0) },
            .moodTags:   { taggingVM.moodTags.append($0) },
        ]
    }

    private var listRemoveBindings: [EditableField: (String) -> Void] {
        [
            .colours:    { value in taggingVM.colours.removeAll(where: { $0 == value }) },
            .customTags: { tag   in taggingVM.tags.removeAll(where: { $0 == tag }) },
            .moodTags:   { mood  in taggingVM.moodTags.removeAll(where: { $0 == mood }) },
        ]
    }

    private var listReadBindings: [EditableField: () -> [String]] {
        [
            .colours:    { taggingVM.colours },
            .customTags: { taggingVM.tags },
            .moodTags:   { taggingVM.moodTags },
        ]
    }
}
