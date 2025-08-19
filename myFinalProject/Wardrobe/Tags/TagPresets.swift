//
//  TagPresets.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import Foundation

enum SeasonOpt: String, CaseIterable, Identifiable {
    case Summer, Winter, Spring, Autumn
    var id: String { rawValue }
}

enum DressCodeOpt: String, CaseIterable, Identifiable {
    case Smart = "Smart"
    case SmartCasual = "Smart Casual"
    case Casual = "Casual"
    var id: String { rawValue }
}

enum CategoryOpt: String, CaseIterable, Identifiable {
    case Dress, Top, Bottom, Shoes, Outerwear, Bag, Accessory
    var id: String { rawValue }
}

enum TagPresets {
    static let styles: [String] = [
        "Minimal","Sporty","Chic","Classy","Elegant","Streetwear","Boho","Preppy","Edgy","Vintage",
        "Romantic","Trendy","Gym","Office","Party","Smart","Smart Casual","Casual"
    ].sorted()

    static let designs: [String] = [
        "Solid","Striped","Checked","Plaid","Polka Dot","Floral","Animal Print","Graphic","Logo",
        "Ribbed","Cable Knit","Lace","Ruffle","Quilted","Embroidered","Sequins","Mesh","Sheer","Brocade","Textured"
    ].sorted()

    static let materials: [String] = [
        "Cotton","Denim","Wool","Silk","Linen","Leather","Faux Leather","Suede","Satin","Cashmere",
        "Nylon","Polyester","Canvas","Corduroy","Velvet","Jersey","Knit","Fleece","Tweed","Mesh","Chiffon","Organza"
    ].sorted()

    static let customTagSuggestions: [String] = [
        "Gold","Silver","Denim","Minimal","Chic","Sporty","Gym","Office","Beach","Travel",
        "Neutral","Pastel","Earthy","Monochrome","Statement","Vintage","Sustainable","Comfy",
        "Oversized","Slim","High-Waist","Low-Rise","Layering","Party","Date Night","Wedding",
        "Rainy","Snow","Summer","Winter","Spring","Autumn"
    ].sorted()

    static let moodTagSuggestions: [String] = [
        "Happy","Calm","Bold","Cozy","Confident","Edgy","Playful","Professional","Romantic",
        "Relaxed","Energetic","Minimal","Elegant","Sporty","Chic"
    ].sorted()
}
