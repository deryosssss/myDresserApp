//
//  TagPickers.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import SwiftUI
// MultiSelectList → toggle items in a Set<String> with checkmarks.
// SingleSelectList → pick exactly one item with a checkmark.
// SingleMenuWithCustom → choose from a menu or type your own value.
// SubcategoryPicker → segmented category tabs + subcategory list; keeps selections valid and context-aware.

/// Multi-select list with independent rows and checkmarks.
struct MultiSelectList: View {
    let title: String
    let options: [String]
    @Binding var selection: Set<String>

    var body: some View {
        Form {
            Section(header: Text(title)) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        if selection.contains(opt) { selection.remove(opt) } else { selection.insert(opt) }
                    } label: {
                        HStack {
                            Text(opt); Spacer()
                            Image(systemName: selection.contains(opt) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selection.contains(opt) ? .brandGreen : .secondary)
                        }
                    }
                }
            }
        }
    }
}

/// Single-select list with a checkmark.
struct SingleSelectList: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Form {
            Section(header: Text(title)) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        selection = opt
                    } label: {
                        HStack {
                            Text(opt); Spacer()
                            if selection == opt {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.brandGreen)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Single menu with “type your own” field.
struct SingleMenuWithCustom: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    @State private var customInput: String = ""

    var body: some View {
        Form {
            Section(header: Text(title)) {
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                HStack {
                    TextField("Or type your own \(title.lowercased())", text: $customInput)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Button("Use") {
                        let val = TagText.normalize(customInput)
                        guard !val.isEmpty else { return }
                        selection = val; customInput = ""
                    }
                    .disabled(TagText.normalize(customInput).isEmpty)
                }
            }
        }
    }
}

/// Segmented category tabs + subcategory list.
/// - Picks the starting tab from `categoryContext` if possible.
/// - Keeps the current subcategory valid when switching tabs.
/// - Seeds a sensible default subcategory if none is chosen.
/// 
struct SubcategoryPicker: View {
    let categoryContext: String
    @Binding var selection: String

    // Selected segmented tab (canonical)
    @State private var selectedTab: String = SubcategoryCatalog.allTabs.first!

    init(categoryContext: String, selection: Binding<String>) {
        self.categoryContext = categoryContext
        self._selection = selection

        // Seed the segmented control to the canonical category if available
        if let canon = SubcategoryCatalog.canonicalCategory(categoryContext) {
            _selectedTab = State(initialValue: canon)
        } else {
            _selectedTab = State(initialValue: SubcategoryCatalog.allTabs.first!)
        }
    }

    var body: some View {
        Form {
            // Category tabs (always visible so users can browse)
            Section(header: Text("Category")) {
                Picker("Category", selection: $selectedTab) {
                    ForEach(SubcategoryCatalog.allTabs, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            // Subcategories for the selected tab
            Section(header: Text("Subcategory")) {
                let options = SubcategoryCatalog.options(for: selectedTab)
                ForEach(options, id: \.self) { opt in
                    Button {
                        selection = opt
                    } label: {
                        HStack {
                            Text(opt)
                            Spacer()
                            if selection == opt {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandGreen)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Ensure we show subcategories for context tab immediately,
            // and choose a sensible default if nothing selected / invalid.
            let options = SubcategoryCatalog.options(for: selectedTab)
            if selection.isEmpty || !options.contains(selection) {
                selection = options.first ?? ""
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Switching tabs: keep selection valid for the new tab
            let options = SubcategoryCatalog.options(for: newTab)
            if !options.contains(selection) {
                selection = options.first ?? ""
            }
        }
    }
}

