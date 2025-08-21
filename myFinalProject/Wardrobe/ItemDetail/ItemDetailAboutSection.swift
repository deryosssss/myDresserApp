//
//  ItemDetailAboutSection.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//
//  1) If the item has colours, render a horizontal row of colour chips (resolving names → hex) with an edit button.
//  2) Render single-value attributes as tappable "chip rows" that open the inline editor.
//  3) Render multi-value attributes (tags) as chip sections that open the editor for that field.
//  4) Wrap everything in a styled card (padding, corner radius, shadow).
//

import SwiftUI

struct ItemDetailAboutSection: View {
    let item: WardrobeItem                                  // source of truth for displayed attributes
    var onEditColours: () -> Void                           // callback to edit the colours array
    var onEditSingleField: (_ field: EditableField, _ current: String) -> Void // callback to edit a single field

    var body: some View {
        VStack(spacing: 16) {                               // vertical stack of sections
            if !item.colours.isEmpty {                      // show colours section only if present
                VStack(alignment: .leading, spacing: 6) {
                    Text("Colours").bold()
                        .padding(.top).padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) { // horizontally scrollable chips
                        HStack(spacing: 6) {
                            ForEach(item.colours, id: \.self) { name in
                                // Normalize the key and try to resolve a hex from the item's lookup table
                                let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                let resolvedHex = item.colorHexByName[key] ?? name
                                let bg = Color(hex: resolvedHex) ?? .gray

                                // Pill chip with dynamic foreground color for contrast
                                Text(name.capitalized)
                                    .font(.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(bg)
                                    .foregroundColor(Color.isDark(hex: resolvedHex) ? .white : .black)
                                    .cornerRadius(12)
                            }
                            TinyEditButton { onEditColours() } // small edit affordance for colours
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // Single-value attributes (tap → edit that specific field with current value)
            chipRow("Category",      item.category,      .category)
            chipRow("Sub-Category",  item.subcategory,   .subcategory)
            chipRow("Length",        item.length,        .length)
            chipRow("Style",         item.style,         .style)
            chipRow("Pattern",       item.designPattern, .designPattern)
            chipRow("Closure",       item.closureType,   .closureType)
            chipRow("Fit",           item.fit,           .fit)
            chipRow("Material",      item.material,      .material)

            // Multi-value attributes (tap → open editor; chips rendered inside custom views)
            chipSection("Custom Tags", item.customTags, .customTags)
            chipRow("Dress Code",     item.dressCode,    .dressCode)
            chipRow("Season",         item.season,       .season)
            chipRow("Size",           item.size,         .size)
            chipSection("Mood Tags",  item.moodTags,     .moodTags)
        }
        .padding(.vertical)                                  // card-like styling
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    // Helper: builds a single-line chip row and wires up the edit action with current value.
    private func chipRow(_ title: String, _ text: String, _ field: EditableField) -> some View {
        ChipRowView(title: title, text: text) {
            onEditSingleField(field, text)
        }
    }

    // Helper: builds a multi-chip section and opens the editor (empty current value by design).
    private func chipSection(_ title: String, _ chips: [String], _ field: EditableField) -> some View {
        ChipSectionView(title: title, chips: chips) {
            onEditSingleField(field, "")
        }
    }
}
