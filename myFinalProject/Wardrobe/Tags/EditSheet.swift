// EditSheet.swift
// myFinalProject
//
// Created by Derya Baglan on 06/08/2025.
//
//
import SwiftUI

// EditSheet is a polymorphic editor: it renders different pickers/editors depending on EditableField.
// It reads/writes values through closures supplied by the parent (for single values and list fields).
// It primes local selection state from draftText and saves back to draftText and the appropriate binding on “Save”.
// Subcategory choices are scoped by category (currentCategory() + SubcategoryCatalog guard).

struct EditSheet: View {
    @Binding var draftText: String
    @Binding var editingField: EditableField?
    let field: EditableField

    // Existing plumbing from caller
    let singleBindings:    [EditableField:(String)->Void]
    let listAddBindings:   [EditableField:(String)->Void]
    let listRemoveBindings:[EditableField:(String)->Void]
    let listReadBindings:  [EditableField:() -> [String]]
    var currentCategory: () -> String = { "" }

    @Environment(\.dismiss) private var dismiss
    @State private var multiSelection = Set<String>()
    @State private var singleSelection = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Edit \(field.title)")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { saveAndDismiss() } }
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
            SubcategoryPicker(
                categoryContext: currentCategory(),
                selection: $singleSelection
            )

        case .style:
            SingleMenuWithCustom(title: "Style",
                                 options: TagPresets.styles,
                                 selection: $singleSelection)

        case .designPattern:
            SingleMenuWithCustom(title: "Design",
                                 options: TagPresets.designs,
                                 selection: $singleSelection)

        case .material:
            SingleMenuWithCustom(title: "Material",
                                 options: TagPresets.materials,
                                 selection: $singleSelection)

        case .customTags:
            MultiTagEditor(title: "Custom Tags",
                           suggestions: TagPresets.customTagSuggestions,
                           initial: Set(listReadBindings[field]?() ?? []),
                           onToggle: { tag, on in (on ? listAddBindings[field] : listRemoveBindings[field])?(tag) },
                           onCustomAdd: { tag in listAddBindings[field]?(tag) })

        case .moodTags:
            MultiTagEditor(title: "Mood Tags",
                           suggestions: TagPresets.moodTagSuggestions,
                           initial: Set(listReadBindings[field]?() ?? []),
                           onToggle: { tag, on in (on ? listAddBindings[field] : listRemoveBindings[field])?(tag) },
                           onCustomAdd: { tag in listAddBindings[field]?(tag) })

        case .colours:
            ListFieldEditor(field: field,
                            items: listReadBindings[field]?() ?? [],
                            draftText: $draftText,
                            onAdd: { listAddBindings[field]?($0) },
                            onRemove: { listRemoveBindings[field]?($0) })

        default:
            SingleFieldEditor(field: field, draftText: $draftText)
        }
    }

    // MARK: - Save / Prime

    private func primeStateFromDraft() {
        switch field {
        case .season, .dressCode:
            multiSelection = Set(draftText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        case .category, .subcategory, .style, .designPattern, .material:
            singleSelection = draftText
        default: break
        }
    }

    private func saveAndDismiss() {
        switch field {
        case .season, .dressCode:
            draftText = multiSelection.sorted().joined(separator: ", ")

        case .category:
            draftText = singleSelection

        case .subcategory:
            // ensure layered validity
            let cat = currentCategory()
            let allowed = SubcategoryCatalog.options(for: cat)
            draftText = allowed.contains(singleSelection) ? singleSelection : ""
            // (optional) you could also show a toast/alert if it got cleared

        case .style, .designPattern, .material:
            draftText = singleSelection

        default:
            break
        }

        if ![.colours, .customTags, .moodTags].contains(field) {
            singleBindings[field]?(draftText)
        }
        dismiss()
    }
}

// MARK: - Primitive text editors

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
                        Text(item); Spacer()
                        Button(role: .destructive) { onRemove(item) } label: { Image(systemName: "minus.circle") }
                    }
                }
                HStack {
                    TextField("New \(field.title.dropLast())", text: $draftText)
                    Button {
                        let tag = TagText.normalize(draftText)
                        guard !tag.isEmpty else { return }
                        onAdd(tag); draftText = ""
                    } label: { Image(systemName: "plus.circle.fill") }
                    .disabled(TagText.normalize(draftText).isEmpty)
                }
            }
        }
    }
}
