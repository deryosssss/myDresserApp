//
//  Outfit.swift
//  myFinalProject
//
//  Created by Derya Baglan on 07/08/2025.
//


import Foundation
import FirebaseFirestore

struct Outfit: Identifiable, Codable {
    @DocumentID var id: String?

    var name:        String
    var description: String?
    var imageURL:    String

    /// URLs of the individual item images making up this outfit
    var itemImageURLs: [String]

    /// IDs of the wardrobe items included in the outfit (MUST match Firestore field "itemIds")
    var itemIds:     [String]

    var tags:        [String]
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var lastWorn:  Date?
    var wearCount:   Int
    var isFavorite:  Bool
    var source:      String // "manual" or "ai"

    // Coding keys match the intended Firestore field names.
    enum CodingKeys: String, CodingKey {
        case name, description, imageURL, itemImageURLs, itemIds, tags, createdAt, lastWorn, wearCount, isFavorite, source
    }

    // Convenience init (lets us create from fallbacks easily)
    init(
        id: String? = nil,
        name: String = "",
        description: String? = nil,
        imageURL: String = "",
        itemImageURLs: [String] = [],
        itemIds: [String] = [],
        tags: [String] = [],
        createdAt: Date? = nil,
        lastWorn: Date? = nil,
        wearCount: Int = 0,
        isFavorite: Bool = false,
        source: String = "manual"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.itemImageURLs = itemImageURLs
        self.itemIds = itemIds
        self.tags = tags
        self.createdAt = createdAt
        self.lastWorn = lastWorn
        self.wearCount = wearCount
        self.isFavorite = isFavorite
        self.source = source
    }

    // Safe decoding: if a field is absent in Firestore, we provide a sensible default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        name          = try c.decodeIfPresent(String.self,  forKey: .name)        ?? ""
        description   = try c.decodeIfPresent(String.self,  forKey: .description)
        imageURL      = try c.decodeIfPresent(String.self,  forKey: .imageURL)    ?? ""
        itemImageURLs = try c.decodeIfPresent([String].self,forKey: .itemImageURLs) ?? []
        itemIds       = try c.decodeIfPresent([String].self,forKey: .itemIds)     ?? []
        tags          = try c.decodeIfPresent([String].self,forKey: .tags)        ?? []

        // Timestamps may arrive as Firebase Timestamp when decoding from Firestore
        if let ts = try c.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = ts.dateValue()
        } else {
            createdAt = nil
        }
        if let ts = try c.decodeIfPresent(Timestamp.self, forKey: .lastWorn) {
            lastWorn = ts.dateValue()
        } else {
            lastWorn = nil
        }

        wearCount    = try c.decodeIfPresent(Int.self,   forKey: .wearCount)   ?? 0
        isFavorite   = try c.decodeIfPresent(Bool.self,  forKey: .isFavorite)  ?? false
        source       = try c.decodeIfPresent(String.self,forKey: .source)      ?? "manual"
    }
}
