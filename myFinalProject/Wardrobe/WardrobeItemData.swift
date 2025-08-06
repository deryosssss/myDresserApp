//
//  WardrobeItemData.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import Foundation
import FirebaseFirestore

/// Represents a single wardrobe item stored in Firestore.
struct WardrobeItem: Identifiable, Codable {
    @DocumentID var id: String?
    
    // MARK: — Core metadata
    var imageURL: String
    var category: String
    var subcategory: String
    var length: String
    var style: String
    var designPattern: String
    var closureType: String
    var fit: String
    var material: String
    var fastening: String?
    var dressCode: String
    var season: String
    var size: String

    // MARK: — Tag lists
    var colours: [String]
    var customTags: [String]
    var moodTags: [String]

    // MARK: — Timestamps & Flags
    @ServerTimestamp var addedAt: Date?
    @ServerTimestamp var lastWorn: Date?
    var isFavorite: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, imageURL, category, subcategory, length, style, designPattern,
             closureType, fit, material, fastening, dressCode, season, size,
             colours, customTags, moodTags, addedAt, lastWorn, isFavorite
    }

    /// Converts this item into a dictionary suitable for Firestore updates.
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "imageURL":      imageURL,
            "category":      category,
            "subcategory":   subcategory,
            "length":        length,
            "style":         style,
            "designPattern": designPattern,
            "closureType":   closureType,
            "fit":           fit,
            "material":      material,
            "dressCode":     dressCode,
            "season":        season,
            "size":          size,
            "colours":       colours,
            "customTags":    customTags,
            "moodTags":      moodTags,
            "isFavorite":    isFavorite
        ]
        if let f = fastening {
            dict["fastening"] = f
        }
        if let lw = lastWorn {
            dict["lastWorn"] = Timestamp(date: lw)
        }
        return dict
    }
}
