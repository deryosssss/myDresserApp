// EditSheet.swift
// myFinalProject
//
// Created by Derya Baglan on 06/08/2025.
//

import SwiftUI

// MARK: - Fixed option sets

private enum SeasonOpt: String, CaseIterable, Identifiable {
    case Summer, Winter, Spring, Autumn
    var id: String { rawValue }
}

private enum DressCodeOpt: String, CaseIterable, Identifiable {
    case Smart = "Smart"
    case SmartCasual = "Smart Casual"
    case Casual = "Casual"
    var id: String { rawValue }
}

private enum CategoryOpt: String, CaseIterable, Identifiable {
    case Dress, Top, Bottom, Shoes, Outerwear, Bag, Accessory
    var id: String { rawValue }
}

private func subcategories(for category: String) -> [String] {
    switch category.lowercased() {
    case "dress":
        return ["Dress", "Gown", "Jumpsuit", "Overall"]
    case "top":
        return ["Top", "Shirt", "Blouse", "T-Shirt", "Sweater", "Hoodie", "Cardigan", "Tank"]
    case "bottom":
        return ["Pants", "Jeans", "Skirt", "Shorts", "Trouser", "Trousers", "Leggings", "Trackpants"]
    case "shoes":
        return ["Sneaker", "Trainer", "Boots", "Heels", "Sandals", "Loafers"]
    case "outerwear":
        return ["Jacket", "Coat", "Blazer", "Parka", "Outerwear"]
    case "bag":
        return ["Handbag", "Backpack", "Tote", "Crossbody", "Purse", "Wallet"]
    case "accessory":
        return ["Belt", "Scarf", "Hat", "Cap", "Jewellery", "Jewelry", "Glove"]
    default:
        // Union of all if category not set yet
        return Array(Set(
            subcategories(for: "dress") +
            subcategories(for: "top") +
            subcategories(for: "bottom") +
            subcategories(for: "shoes") +
            subcategories(for: "outerwear") +
            subcategories(for: "bag") +
            subcategories(for: "accessory")
        )).sorted()
    }
}

// MARK: - Edit Sheet

struct EditSheet: View {
    @Binding var draftText: String
    @Binding var editingField: EditableField?
    let field: EditableField

    // Existing plumbing from caller
    let singleBindings:    [EditableField:(String)->Void]
    let listAddBindings:   [EditableField:(String)->Void]
    let listRemoveBindings:[EditableField:(String)->Void]
    let listReadBindings:  [EditableField:() -> [String]]

    /// So Subcategory options reflect the current Category
    var currentCategory: () -> String = { "" }

    @Environment(\.dismiss) private var dismiss

    // Local UI state for multi/single option pickers
    @State private var multiSelection = Set<String>()
    @State private var singleSelection = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Edit \(field.title)")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveAndDismiss() }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .onAppear { primeStateFromDraft() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch field {
        case .season:
            MultiSelectList(title: "Season",
                            options: SeasonOpt.allCases.map(\.rawValue),
                            selection: $multiSelection)

        case .dressCode:
            MultiSelectList(title: "Dress Code",
                            options: DressCodeOpt.allCases.map(\.rawValue),
                            selection: $multiSelection)

        case .category:
            SingleSelectList(title: "Category",
                             options: CategoryOpt.allCases.map(\.rawValue),
                             selection: $singleSelection)

        case .subcategory:
            SingleSelectList(title: "Subcategory",
                             options: subcategories(for: currentCategory()),
                             selection: $singleSelection)

        // List-style editors (unchanged)
        case .colours, .customTags, .moodTags:
            ListFieldEditor(
                field:     field,
                items:     listReadBindings[field]?() ?? [],
                draftText: $draftText,
                onAdd:     { listAddBindings[field]?($0) },
                onRemove:  { listRemoveBindings[field]?($0) }
            )

        // Basic single text fallback
        default:
            SingleFieldEditor(field: field, draftText: $draftText)
        }
    }

    // MARK: - Save / Prime

    private func primeStateFromDraft() {
        switch field {
        case .season, .dressCode:
            multiSelection = Set(
                draftText
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
        case .category, .subcategory:
            singleSelection = draftText
        default:
            break
        }
    }

    private func saveAndDismiss() {
        switch field {
        case .season, .dressCode:
            draftText = multiSelection.sorted().joined(separator: ", ")

        case .category, .subcategory:
            draftText = singleSelection

        default:
            break
        }
        // For list fields, commit is handled inside ListFieldEditor
        if ![.colours, .customTags, .moodTags].contains(field) {
            singleBindings[field]?(draftText)
        }
        dismiss()
    }
}

// MARK: - Primitive editors

private struct SingleFieldEditor: View {
    let field: EditableField
    @Binding var draftText: String

    var body: some View {
        Form {
            Section(header: Text(field.title)) {
                TextField("Enter \(field.title)", text: $draftText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }
        }
    }
}

private struct ListFieldEditor: View {
    let field: EditableField
    let items: [String]
    @Binding var draftText: String
    let onAdd: (String)->Void
    let onRemove: (String)->Void

    var body: some View {
        Form {
            Section(header: Text(field.title)) {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Text(item)
                        Spacer()
                        Button(role: .destructive) { onRemove(item) } label: {
                            Image(systemName: "minus.circle")
                        }
                    }
                }
                HStack {
                    TextField("New \(field.title.dropLast())", text: $draftText)
                    Button {
                        let trimmed = draftText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed)
                        draftText = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(draftText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Multi / Single selection UIs

/// Multi-select list with independent rows and checkmarks
private struct MultiSelectList: View {
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
                            Text(opt)
                            Spacer()
                            if selection.contains(opt) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandGreen)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Single-select list with a checkmark
private struct SingleSelectList: View {
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
    }
}
