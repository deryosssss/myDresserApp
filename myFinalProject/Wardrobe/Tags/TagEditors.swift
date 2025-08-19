//
//  TagEditors.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import SwiftUI

// TagText.normalize standardizes tag strings.
// MultiTagEditor lets users add free-form tags, pick from suggestions, search/filter suggestions, and see/remove selected chips. It reports changes back via onToggle / onCustomAdd.
// WrapChips renders the selected tags as removable chips.
// FlexibleView is a tiny “flow layout” to wrap chips across lines.

enum TagText {
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .capitalized
    }
}

struct MultiTagEditor: View {
    let title: String
    let suggestions: [String]
    let initial: Set<String>
    let onToggle: (_ tag: String, _ isOn: Bool) -> Void
    let onCustomAdd: (_ tag: String) -> Void

    @State private var selected: Set<String> = []
    @State private var customInput: String = ""
    @State private var search: String = ""

    var body: some View {
        Form {
            Section {
                if !selected.isEmpty {
                    WrapChips(tags: Array(selected).sorted(), removable: true) { tag in
                        selected.remove(tag); onToggle(tag, false)
                    }
                    .padding(.vertical, 4)
                }

                HStack {
                    TextField("Add a tag", text: $customInput)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Button {
                        let tag = TagText.normalize(customInput)
                        guard !tag.isEmpty else { return }
                        if !selected.contains(tag) {
                            selected.insert(tag); onCustomAdd(tag)
                        }
                        customInput = ""
                    } label: { Image(systemName: "plus.circle.fill") }
                    .disabled(TagText.normalize(customInput).isEmpty)
                }
            } header: {
                Text(title)
            } footer: {
                Text("Tip: tags like “Sporty”, “Chic”, “Gold”, “Silver”, “Denim”, “Minimal”, “Gym” make prompts more accurate.")
            }

            Section(header: Text("Suggestions")) {
                TextField("Filter suggestions", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                let filtered = suggestions.filter { search.isEmpty ? true : $0.localizedCaseInsensitiveContains(search) }
                if filtered.isEmpty {
                    Text("No suggestions").foregroundStyle(.secondary)
                } else {
                    ForEach(filtered, id: \.self) { tag in
                        Button {
                            if selected.contains(tag) { selected.remove(tag); onToggle(tag, false) }
                            else { selected.insert(tag); onToggle(tag, true) }
                        } label: {
                            HStack {
                                Text(tag); Spacer()
                                if selected.contains(tag) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.brandGreen)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            selected = initial.map(TagText.normalize).filter { !$0.isEmpty }.reduce(into: Set<String>()) { $0.insert($1) }
        }
    }
}

// Chips

struct WrapChips: View {
    let tags: [String]
    var removable = false
    var onRemove: (String) -> Void = { _ in }

    var body: some View {
        FlexibleView(data: tags, spacing: 8, alignment: .leading) { tag in
            HStack(spacing: 6) {
                Text(tag)
                if removable {
                    Button { onRemove(tag) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Capsule().fill(Color(.systemGray6)))
        }
    }
}

/// Very small flexible layout for chips
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.spacing = spacing; self.alignment = alignment; self.content = content
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geo in
            ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
                ForEach(Array(data), id: \.self) { item in
                    content(item)
                        .padding(4)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width { width = 0; height -= d.height + spacing }
                            let result = width; width -= d.width + spacing; return result
                        }
                        .alignmentGuide(.top) { _ in let r = height; return r }
                }
            }
        }
        .frame(height: 80) // simple placeholder height; GeometryReader will expand as needed
    }
}
