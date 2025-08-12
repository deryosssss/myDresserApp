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
    
    // ← Add this stored property back so your UI’s loops compile untouched:
    /// URLs of the individual item images making up this outfit
    var itemImageURLs: [String]
    
    // You can still keep itemIDs if you need them elsewhere:
    var itemIDs:     [String]         // references to the garments
    
    var tags:        [String]         // e.g. ["summer","brunch","elegant"]
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var lastWorn:  Date?
    var wearCount:   Int
    var isFavorite:  Bool
    var source:      String          // "manual" or "ai"
}
