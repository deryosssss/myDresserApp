//
//  WardrobeItemData.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import Foundation

struct WardrobeItemData: Codable {
    let imageURL: String        // or storage path, if you upload the image to Storage
    let detectedItems: [String]
    let colors: [String]
    let labels: [String]
    let addedAt: Date
}
