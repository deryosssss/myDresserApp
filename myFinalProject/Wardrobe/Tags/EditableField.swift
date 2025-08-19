//
//  EditableField.swift
//  myFinalProject
//
//  Created by Derya Baglan on 06/08/2025.
//

import Foundation
/// A shared set of field identifiers used anywhere the app edits a single value
/// (e.g., `size`) or a list/multi-select value (e.g., `colours`, `customTags`).
/// Conforms to:
/// - `RawRepresentable` via `String` raw values (auto-uses the case name)
/// - `CaseIterable` so you can iterate all fields
/// - `Identifiable` so it can be used directly in SwiftUI lists
/// - `CustomStringConvertible` to provide a human-readable label via `description`

/// Shared enum for any view that needs to edit a single or list field.
enum EditableField: String, CaseIterable, Identifiable, CustomStringConvertible {
    case category, subcategory, length, style, designPattern
    case closureType, fit, material, dressCode, season, size
    case colours, customTags, moodTags

    var id: String { rawValue }

    /// Human‐readable title
    var title: String {
        rawValue
            .replacingOccurrences(of: "([A-Z])", with: " $1",
                                  options: .regularExpression)
            .capitalized
    }

    var description: String { title }
}
