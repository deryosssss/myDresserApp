// TaggedItemPreviewView.swift
// myFinalProject
//
//  Created by Derya Baglan on 01/08/2025
//
//  1) Shows the auto-tagged image and metadata so you can review & edit before saving.
//  2) Lets you tweak chips (category/length/etc.), colour tags (with hex mapping), source, gender, favorite.
//  3) On Save → uploads image + saves WardrobeItem; on Delete → clears form and dismisses.
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

    // Small info banner to explain auto-categorisation
    @State private var showAutoBanner: Bool = true

    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Review & Save")
                    .font(AppFont.spicyRice(size: 28))
                    .padding(.top)
                    .aid("preview.title")

                // Dismissible info banner about auto-tags
                if showAutoBanner {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").imageScale(.large)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-categorised").font(.subheadline).bold()
                            Text("We automatically categorised and tagged this item. Please review the details below and make any changes before saving. Note - The more the tags the better our outfit recommendations will be!")
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showAutoBanner = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.footnote.weight(.semibold))
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss info")
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .aid("preview.banner")
                }

                // Large image preview
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .background(Color(white: 0.93))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .aid("preview.image")

                // ===== Colours (chips) =====
                if !taggingVM.colours.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Colours").bold().padding(.horizontal)
                            .aid("preview.colours.title")

                        // Horizontal list of colour chips, using stored hex map where possible
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(taggingVM.colours, id: \.self) { name in
                                    let key = norm(name)
                                    let hex = taggingVM.colorHexByName[key] ?? name
                                    let bg = Color(hex: hex) ?? .gray

                                    Text(name.capitalized)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(bg)
                                        .foregroundColor(Color.isDark(hex: hex) ? .white : .black)
                                        .cornerRadius(12)
                                        .aid("preview.colour.\(key)")
                                }
                                TinyEditButton { startEditing(.colours) }              // open edit sheet for colours
                                    .aid("preview.colours.edit")
                            }
                            .padding(.horizontal)
                        }
                        .aid("preview.colours.scroll")
                    }
                }

                // ===== Single-value chips (tap to edit) =====
                ChipRowView(title: "Category",         text: taggingVM.category)      { startEditing(.category) }
                    .aid("preview.category")
                ChipRowView(title: "Sub Category",     text: taggingVM.subcategory)   { startEditing(.subcategory) }
                    .aid("preview.subcategory")
                ChipRowView(title: "Length",           text: taggingVM.length)        { startEditing(.length) }
                    .aid("preview.length")
                ChipRowView(title: "Style",            text: taggingVM.style)         { startEditing(.style) }
                    .aid("preview.style")
                ChipRowView(title: "Design / Pattern", text: taggingVM.designPattern) { startEditing(.designPattern) }
                    .aid("preview.design")
                ChipRowView(title: "Closure",          text: taggingVM.closureType)   { startEditing(.closureType) }
                    .aid("preview.closure")
                ChipRowView(title: "Fit",              text: taggingVM.fit)           { startEditing(.fit) }
                    .aid("preview.fit")
                ChipRowView(title: "Material",         text: taggingVM.material)      { startEditing(.material) }
                    .aid("preview.material")

                // ===== Multi-value chips =====
                ChipSectionView(title: "Custom Tags", chips: taggingVM.tags)     { startEditing(.customTags) }
                    .aid("preview.customTags")
                ChipRowView(title: "Dress Code",       text: taggingVM.dressCode) { startEditing(.dressCode) }
                    .aid("preview.dressCode")
                ChipRowView(title: "Season",           text: taggingVM.season)    { startEditing(.season) }
                    .aid("preview.season")
                ChipRowView(title: "Size",             text: taggingVM.size)      { startEditing(.size) }
                    .aid("preview.size")
                ChipSectionView(title: "Mood Tags",    chips: taggingVM.moodTags) { startEditing(.moodTags) }
                    .aid("preview.moodTags")

                // MARK: — More (Source / Gender / Favorite)
                VStack(alignment: .leading, spacing: 8) {
                    Text("More").bold().padding(.horizontal)
                        .aid("preview.more.title")

                    // Source type (camera/gallery/web)
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
                        .aid("preview.source.picker")
                    }
                    .padding(.horizontal)

                    // Gender presentation
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
                        .aid("preview.gender.picker")
                    }
                    .padding(.horizontal)

                    // Favorite toggle
                    Toggle(isOn: $taggingVM.isFavorite) {
                        Text("Mark as Favorite")
                    }
                    .padding(.horizontal)
                    .aid("preview.favorite.toggle")
                }
                .padding(.top, 4)

                // Save / Delete actions
                HStack(spacing: 12) {
                    Button("Delete") {
                        taggingVM.clearAll()   // reset form state
                        onDismiss()            // close sheet
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandPink)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .aid("preview.delete")

                    Button("Save") {
                        taggingVM.uploadAndSave(image: originalImage) // upload + Firestore save
                        onDismiss()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandGreen)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .aid("preview.save")
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        // Edit modal (single & list modes share one EditSheet)
        .sheet(item: $editingField) { field in
            EditSheet(
                draftText:          $draftText,
                editingField:       $editingField,
                field:              field,
                singleBindings:     singleBindings,
                listAddBindings:    listAddBindings,
                listRemoveBindings: listRemoveBindings,
                listReadBindings:   listReadBindings,
                currentCategory:    { taggingVM.category }
            )
        }
        .aid("preview.root")
    }

    // MARK: - Bindings & Editing

    private func startEditing(_ field: EditableField) {
        // Seed draft text for single-value fields; blank for list fields
        switch field {
        case .colours, .customTags, .moodTags:
            draftText = ""
        case .category:      draftText = taggingVM.category
        case .subcategory:   draftText = taggingVM.subcategory
        case .length:        draftText = taggingVM.length
        case .style:         draftText = taggingVM.style
        case .designPattern: draftText = taggingVM.designPattern
        case .closureType:   draftText = taggingVM.closureType
        case .fit:           draftText = taggingVM.fit
        case .material:      draftText = taggingVM.material
        case .dressCode:     draftText = taggingVM.dressCode
        case .season:        draftText = taggingVM.season
        case .size:          draftText = taggingVM.size
        default:             draftText = ""
        }
        editingField = field
    }

    // Single-field writers (called by EditSheet on Save)
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

    // List add actions (append item and maintain colour hex map when user typed a hex)
    private var listAddBindings: [EditableField: (String) -> Void] {
        [
            .colours:    {
                taggingVM.colours.append($0)
                let key = norm($0)
                let cleaned = $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                if cleaned.count == 6, Int(cleaned, radix: 16) != nil {
                    taggingVM.colorHexByName[key] = cleaned
                }
            },
            .customTags: { taggingVM.tags.append($0) },
            .moodTags:   { taggingVM.moodTags.append($0) },
        ]
    }

    // List remove actions (also purge colour hex map entry)
    private var listRemoveBindings: [EditableField: (String) -> Void] {
        [
            .colours:    { value in
                taggingVM.colours.removeAll(where: { $0 == value })
                taggingVM.colorHexByName.removeValue(forKey: norm(value))
            },
            .customTags: { tag   in taggingVM.tags.removeAll(where: { $0 == tag }) },
            .moodTags:   { mood  in taggingVM.moodTags.removeAll(where: { $0 == mood }) },
        ]
    }

    // List readers (EditSheet reads from these to show current chips)
    private var listReadBindings: [EditableField: () -> [String]] {
        [
            .colours:    { taggingVM.colours },
            .customTags: { taggingVM.tags },
            .moodTags:   { taggingVM.moodTags },
        ]
    }
}
