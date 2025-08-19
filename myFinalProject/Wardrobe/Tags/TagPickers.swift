//
//  TagPickers.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import SwiftUI

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
