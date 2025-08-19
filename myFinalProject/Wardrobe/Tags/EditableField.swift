//
//  EditableField.swift
//  myFinalProject
//
//  Created by Derya Baglan on 06/08/2025.
//

import Foundation

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
