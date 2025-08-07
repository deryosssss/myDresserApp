// EditSheet.swift
// myFinalProject
//
// Created by Derya Baglan on 06/08/2025.
//

import SwiftUI

struct EditSheet: View {
    @Binding var draftText: String
    @Binding var editingField: EditableField?
    let field: EditableField

    let singleBindings:    [EditableField:(String)->Void]
    let listAddBindings:   [EditableField:(String)->Void]
    let listRemoveBindings:[EditableField:(String)->Void]
    let listReadBindings:  [EditableField:() -> [String]]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Edit \(field.title)")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { commit(); dismiss() }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if [.colours, .customTags, .moodTags].contains(field) {
            ListFieldEditor(
                field:     field,
                items:     listReadBindings[field]?() ?? [],
                draftText: $draftText,
                onAdd:     { listAddBindings[field]?($0) },
                onRemove:  { listRemoveBindings[field]?($0) }
            )
        } else {
            SingleFieldEditor(field: field, draftText: $draftText)
        }
    }

    private func commit() {
        guard ![.colours, .customTags, .moodTags].contains(field) else { return }
        singleBindings[field]?(draftText)
    }
}

private struct SingleFieldEditor: View {
    let field: EditableField
    @Binding var draftText: String

    var body: some View {
        Form {
            Section(header: Text(field.title)) {
                TextField("Enter \(field.title)", text: $draftText)
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
                        onAdd(draftText)
                        draftText = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(draftText.isEmpty)
                }
            }
        }
    }
}
