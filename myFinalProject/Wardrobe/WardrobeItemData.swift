//
//  WardrobeItemData.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import Foundation
import FirebaseFirestore

struct WardrobeItem: Identifiable, Codable {
    // MARK: - New types
    enum SourceType: String, Codable, CaseIterable {
        case camera, gallery, web
    }

    // MARK: - Identity & media
    var id: String?
    var userId: String
    var imageURL: String
    /// Storage path of the primary image (authoritative for deletes/migrations)
    var imagePath: String?

    // MARK: - Attributes
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

    /// User-facing names (display order)
    var colours: [String]
    /// Backend lookup used to render chip background colors
    var colorHexByName: [String:String] = [:]
    var customTags: [String]
    var moodTags: [String]

    // MARK: - New persisted fields
    var isFavorite: Bool          // <— persisted favorite
    var sourceType: SourceType    // <— camera / gallery / web
    var gender: String            // <— free text (e.g., Woman / Man / Unisex / Other)

    /// Firestore timestamps
    var addedAt: Date?
    var lastWorn: Date?           // keep last worn

    init(
        id: String? = nil,
        userId: String,
        imageURL: String,
        imagePath: String? = nil,
        category: String,
        subcategory: String,
        length: String,
        style: String,
        designPattern: String,
        closureType: String,
        fit: String,
        material: String,
        fastening: String?,
        dressCode: String,
        season: String,
        size: String,
        colours: [String],
        colorHexByName: [String:String] = [:],   // ✅ accept map
        customTags: [String],
        moodTags: [String],
        // NEW with sensible defaults
        isFavorite: Bool = false,
        sourceType: SourceType = .gallery,
        gender: String = "",
        addedAt: Date? = nil,
        lastWorn: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.imageURL = imageURL
        self.imagePath = imagePath
        self.category = category
        self.subcategory = subcategory
        self.length = length
        self.style = style
        self.designPattern = designPattern
        self.closureType = closureType
        self.fit = fit
        self.material = material
        self.fastening = fastening
        self.dressCode = dressCode
        self.season = season
        self.size = size
        self.colours = colours
        self.colorHexByName = colorHexByName    // ✅ store map
        self.customTags = customTags
        self.moodTags = moodTags
        self.isFavorite = isFavorite
        self.sourceType = sourceType
        self.gender = gender
        self.addedAt = addedAt
        self.lastWorn = lastWorn
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "imageURL": imageURL,
            "category": category,
            "subcategory": subcategory,
            "length": length,
            "style": style,
            "designPattern": designPattern,
            "closureType": closureType,
            "fit": fit,
            "material": material,
            "dressCode": dressCode,
            "season": season,
            "size": size,
            "colours": colours,
            "colorHexByName": colorHexByName,   // ✅ persist map
            "customTags": customTags,
            "moodTags": moodTags,
            "isFavorite": isFavorite,           // NEW
            "sourceType": sourceType.rawValue,  // NEW
            "gender": gender,                   // NEW
            "addedAt": FieldValue.serverTimestamp()
        ]
        if let imagePath { data["imagePath"] = imagePath }
        if let fastening { data["fastening"] = fastening }
        if let lastWorn  { data["lastWorn"]  = lastWorn }
        return data
    }
}

extension WardrobeItem {
    /// Update payload (no addedAt so we don't clobber it).
    var dictionary: [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "imageURL": imageURL,
            "category": category,
            "subcategory": subcategory,
            "length": length,
            "style": style,
            "designPattern": designPattern,
            "closureType": closureType,
            "fit": fit,
            "material": material,
            "dressCode": dressCode,
            "season": season,
            "size": size,
            "colours": colours,
            "colorHexByName": colorHexByName,   // ✅ persist map on updates
            "customTags": customTags,
            "moodTags": moodTags,
            "isFavorite": isFavorite,           // NEW
            "sourceType": sourceType.rawValue,  // NEW
            "gender": gender                    // NEW
        ]

        if let imagePath {
            data["imagePath"] = imagePath
        } else {
            data["imagePath"] = FieldValue.delete()
        }

        if let fastening {
            data["fastening"] = fastening
        } else {
            data["fastening"] = FieldValue.delete()
        }

        if let lastWorn {
            data["lastWorn"] = lastWorn
        } else {
            data["lastWorn"] = FieldValue.delete()
        }

        return data
    }
}
