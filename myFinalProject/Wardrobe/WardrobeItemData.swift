//
//  WardrobeItemData.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import FirebaseFirestore

struct WardrobeItem: Identifiable, Codable {
    @DocumentID var id: String?
    let imageURL: String
    let category: String
    let subcategory: String
    let colours: [String]
    let customTags: [String]
    let length: String
    let style: String
    let designPattern: String
    let closureType: String
    let fit: String
    let material: String
    let fastening: String
    let dressCode: String
    let season: String
    let size: String
    let moodTags: [String]

    @ServerTimestamp
    var addedAt: Date?
}
