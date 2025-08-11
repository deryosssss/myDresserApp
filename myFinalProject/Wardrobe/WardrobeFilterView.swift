//  WardrobeFilterView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
//


import SwiftUI

// MARK: — Color extension for brightness & contrast
extension Color {
    func brightness() -> Double {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Double((r * 299 + g * 587 + b * 114) / 1000)
        #else
        return 1.0
        #endif
    }
    var contrastingTextColor: Color {
        brightness() > 0.5 ? .black : .white
    }
}


struct WardrobeFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: WardrobeViewModel

    // MARK: – Filter state
    @State private var selectedCategory: String = "All"
    @State private var sortBy: String = "Newest"
    @State private var selectedColours: Set<String> = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedDressCode: String = "Any"
    @State private var selectedSeason: String = "All"
    @State private var selectedSize: String = "Any"
    @State private var selectedMaterial: String = "Any"

    // MARK: – Static options
    private let categories  = ["All", "Top", "Outerwear", "Dress", "Bottoms", "Footwear"]
    private let sortOptions = ["Newest", "Oldest", "A → Z", "Z → A"]
    private let tags        = ["Casual", "Formal", "Party", "Sport", "Travel", "Work"]
    private let dressCodes  = ["Any", "Casual", "Business", "Black Tie"]
    private let seasons     = ["All", "Spring", "Summer", "Autumn", "Winter"]
    private let sizes       = ["Any", "XS", "S", "M", "L", "XL"]
    private let materials   = ["Any", "Cotton", "Silk", "Denim", "Leather", "Wool"]

    // MARK: – Colour mapping
    private let colourMap: [String: Color] = [
        "Black": .black,
        "White": .white,
        "Red": .red,
        "Blue": .blue,
        "Green": .green,
        "Yellow": .yellow,
        "Pink": .pink
    ]

    // MARK: – Dynamic colours from user’s wardrobe items
    private var dynamicColours: [String] {
        Array(Set(vm.items.flatMap { $0.colours })).sorted()
    }

    // MARK: — grid layout for non-colour chips
    private let chipColumns = [ GridItem(.adaptive(minimum: 80), spacing: 8) ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        dropdownSection(title: "Category", selection: $selectedCategory, options: categories)
                        dropdownSection(title: "Sort by",   selection: $sortBy,           options: sortOptions)

                        colourPickerSection(
                            title:       "Colours",
                            options:     dynamicColours,
                            selection:   $selectedColours
                        )

                        multiSelectChips(
                            title:     "Tags",
                            options:   tags,
                            selection: $selectedTags
                        )

                        dropdownSection(title: "Dress Code", selection: $selectedDressCode, options: dressCodes)
                        dropdownSection(title: "Season",     selection: $selectedSeason,     options: seasons)
                        dropdownSection(title: "Size",       selection: $selectedSize,       options: sizes)
                        dropdownSection(title: "Material",   selection: $selectedMaterial,   options: materials)
                    }
                    .padding()
                }

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
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset", action: resetFilters)
                }
            }
        }
    }

    // MARK: — Dropdown helper
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

    // MARK: — Colour picker as circles, white gets thin gray border
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
                ForEach(options, id: \.self) { opt in
                    let clr = colourMap[opt] ?? Color(hex: opt) ?? .gray
                    let isSelected = selection.wrappedValue.contains(opt)
                    Circle()
                        .fill(clr)
                        .frame(width: 36, height: 36)
                        .overlay(
                            ZStack {
                                // always show thin border for white
                                if clr == .white {
                                    Circle().stroke(Color.gray, lineWidth: 1)
                                }
                                // highlight selection
                                if isSelected {
                                    Circle().stroke(Color.blue, lineWidth: 3)
                                }
                            }
                        )
                        .onTapGesture {
                            if isSelected {
                                selection.wrappedValue.remove(opt)
                            } else {
                                selection.wrappedValue.insert(opt)
                            }
                        }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: — Chips helper for tags, etc.
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
                            if isSelected {
                                selection.wrappedValue.remove(opt)
                            } else {
                                selection.wrappedValue.insert(opt)
                            }
                        }
                }
            }
        }
    }

    // MARK: — Reset & Apply
    private func resetFilters() {
        selectedCategory   = "All"
        sortBy             = "Newest"
        selectedColours.removeAll()
        selectedTags.removeAll()
        selectedDressCode  = "Any"
        selectedSeason     = "All"
        selectedSize       = "Any"
        selectedMaterial   = "Any"
    }

    private func applyFilters() {
        // TODO: wire these back into your VM
        dismiss()
    }
}

