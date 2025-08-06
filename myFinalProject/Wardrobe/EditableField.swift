//
//  EditableField.swift
//  myFinalProject
//
//  Created by Derya Baglan on 06/08/2025.
//

import Foundation

/// Shared enum for any view that needs to edit a single or list field.
enum EditableField: String, CaseIterable, Identifiable, CustomStringConvertible {
    case category
    case subcategory
    case length
    case style
    case designPattern
    case closureType
    case fit
    case material
    case dressCode
    case season
    case size
    case colours
    case customTags
    case moodTags

    var id: String { rawValue }

    /// Human‐readable title, e.g. “Design Pattern”
    var title: String {
        rawValue
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .capitalized
    }

    var description: String { title }
}
