//
//  WardrobeFilterView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025
//
//  1) Shows filter controls (dropdowns + multi-select chips + colour picker) for the wardrobe list.
//  2) On appear, pre-fills UI from WardrobeViewModel.filters; "Apply" writes back, "Reset" clears.
//  3) Colour chips use per-item stored hex codes when available (fallback to basic names), with contrast tweaks.
//

import SwiftUI

// MARK: — Color extension for brightness & contrast (used by chips if needed)
extension Color {
    func brightness() -> Double {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Double((r * 299 + g * 587 + b * 114) / 1000) // perceived luminance
        #else
        return 1.0
        #endif
    }
    var contrastingTextColor: Color { brightness() > 0.5 ? .black : .white } // readable text on chip bg
}

struct WardrobeFilterView: View {
    @Environment(\.dismiss) private var dismiss                  // close the sheet
    @EnvironmentObject private var vm: WardrobeViewModel         // source of truth for filters/items

    // MARK: – Local filter UI state (mirrors vm.filters while editing)
    @State private var selectedCategory: String = "All"
    @State private var selectedColours: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedDressCode: String = "Any"
    @State private var selectedSeason: String = "All"
    @State private var selectedSize: String = "Any"
    @State private var selectedMaterial: String = "Any"

    // MARK: – Static options (display labels)
    private let categories  = ["All", "Top", "Outerwear", "Dress", "Bottoms", "Footwear"]
    private let tags        = ["Casual", "Formal", "Party", "Sport", "Travel", "Work"]
    private let dressCodes  = ["Any", "Casual", "Business", "Black Tie"]
    private let seasons     = ["All", "Spring", "Summer", "Autumn", "Winter"]
    private let sizes       = ["Any", "XS", "S", "M", "L", "XL"]
    private let materials   = ["Any", "Cotton", "Silk", "Denim", "Leather", "Wool"]

    // MARK: – Fallback colour names → SwiftUI Color (when no hex mapping exists)
    private let fallbackNameMap: [String: Color] = [
        "Black": .black, "White": .white, "Red": .red, "Blue": .blue,
        "Green": .green, "Yellow": .yellow, "Pink": .pink
    ]

    // MARK: – Aggregate colour names from wardrobe (distinct, sorted)
    private var dynamicColours: [String] {
        Array(Set(vm.items.flatMap { $0.colours })).sorted()
    }

    // MARK: – Aggregate name → hex map from all items (normalized keys)
    private var aggregatedColorHexMap: [String: String] {
        func norm(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        var out: [String: String] = [:]
        for item in vm.items {
            for (name, hexRaw) in item.colorHexByName {
                let key = norm(name)
                let hex = hexRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: "#", with: "")
                if hex.count == 6, Int(hex, radix: 16) != nil { out[key] = hex } // only valid 6-char hex
            }
        }
        return out
    }

    // MARK: — Grid layout for non-colour chips
    private let chipColumns = [ GridItem(.adaptive(minimum: 80), spacing: 8) ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        dropdownSection(title: "Category", selection: $selectedCategory, options: categories)

                        multiSelectChips(
                            title:     "Tags",
                            options:   tags,
                            selection: $selectedTags
                        )

                        dropdownSection(title: "Dress Code", selection: $selectedDressCode, options: dressCodes)
                        dropdownSection(title: "Season",     selection: $selectedSeason,     options: seasons)
                        dropdownSection(title: "Size",       selection: $selectedSize,       options: sizes)
                        dropdownSection(title: "Material",   selection: $selectedMaterial,   options: materials)

                        colourPickerSection(
                            title:       "Colours",
                            options:     dynamicColours,
                            selection:   $selectedColours
                        )
                    }
                    .padding()
                }

                // Apply button writes to vm.filters and dismisses
                Button(action: applyFilters) {
                    Text("Apply")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandGreen)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") } // close without applying
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset", action: resetFilters) // restore defaults
                }
            }
            .onAppear {
                // Pre-fill UI state from current filters in VM
                let f = vm.filters
                selectedCategory  = f.category
                selectedColours   = f.colours
                selectedTags      = f.tags
                selectedDressCode = f.dressCode
                selectedSeason    = f.season
                selectedSize      = f.size
                selectedMaterial  = f.material
            }
        }
    }

    // MARK: — Dropdown helper (label + Menu backed by Binding<String>)
    private func dropdownSection(
        title:     String,
        selection: Binding<String>,
        options:   [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
            Menu {
                ForEach(options, id: \.self) { opt in
                    Button(opt) { selection.wrappedValue = opt }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue)
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.black)
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(6)
            }
        }
    }

    // MARK: — Colour picker as circles (uses stored hex when available)
    private func colourPickerSection(
        title:      String,
        options:    [String],
        selection:  Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                ForEach(options, id: \.self) { displayName in
                    let norm = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let hex = aggregatedColorHexMap[norm]                                    // from items
                    let clr = (hex.flatMap { Color(hex: $0) })                               // global Color(hex:)
                              ?? fallbackNameMap[displayName]
                              ?? .gray
                    let isSelected = selection.wrappedValue.contains(displayName)

                    Circle()
                        .fill(clr)
                        .frame(width: 36, height: 36)
                        .overlay(
                            ZStack {
                                if clr == .white { Circle().stroke(Color.gray, lineWidth: 1) } // outline on white
                                if isSelected { Circle().stroke(Color.blue, lineWidth: 3) }    // selection ring
                            }
                        )
                        .onTapGesture {
                            if isSelected { selection.wrappedValue.remove(displayName) }
                            else { selection.wrappedValue.insert(displayName) }
                        }
                        .accessibilityLabel(Text(displayName))
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: — Chips helper for tags, etc. (multi-select)
    private func multiSelectChips(
        title:     String,
        options:   [String],
        selection: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)

            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    let isSelected = selection.wrappedValue.contains(opt)
                    Text(opt)
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(isSelected ? Color.blue.opacity(0.4) : Color(.systemGray5))
                        .cornerRadius(12)
                        .onTapGesture {
                            if isSelected { selection.wrappedValue.remove(opt) }
                            else { selection.wrappedValue.insert(opt) }
                        }
                }
            }
        }
    }

    // MARK: — Reset & Apply
    private func resetFilters() {
        selectedCategory  = "All"
        selectedColours.removeAll()
        selectedTags.removeAll()
        selectedDressCode = "Any"
        selectedSeason    = "All"
        selectedSize      = "Any"
        selectedMaterial  = "Any"
        vm.filters = .default                                   // write defaults back to VM
    }

    private func applyFilters() {
        vm.filters = WardrobeFilters(                            // persist to VM
            category:  selectedCategory,
            colours:   selectedColours,
            tags:      selectedTags,
            dressCode: selectedDressCode,
            season:    selectedSeason,
            size:      selectedSize,
            material:  selectedMaterial
        )
        dismiss()                                                // close the sheet
    }
}
