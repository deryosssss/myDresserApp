//
//  ItemDetailHelpers.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025

//  1) Builds a short "seed prompt" string for an AI outfit generator from a WardrobeItem (includes item id if present).
//  2) Maps a Uniform Type Identifier (UTType) to a (MIME type, file extension) pair, with sensible JPEG fallback.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI

enum ItemDetailHelpers {
    /// Returns a concise prompt for AI that references the item (and MUST include its id if it exists).
    static func aiSeedPrompt(for item: WardrobeItem) -> String {
        let label = [item.category, item.subcategory]               // "Category Subcategory"
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if let id = item.id {
            return "Create outfit ideas that MUST include wardrobe item ID \(id). Item: \(label)." // strict include by id
        } else {
            return "Create outfit ideas built around this item: \(label)."                         // fallback without id
        }
    }

    /// Converts a UTType (if known) to MIME + file extension; defaults to JPEG when unknown.
    static func mimeAndExt(for utType: UTType?) -> (mime: String, ext: String) {
        guard let t = utType else { return ("image/jpeg", "jpg") }  // nil → default JPEG
        if t.conforms(to: .png)  { return ("image/png",  "png") }   // PNG
        if t.conforms(to: .heic) { return ("image/heic", "heic") }  // HEIC (Apple)
        if t.conforms(to: .heif) { return ("image/heif", "heif") }  // HEIF (container)
        return ("image/jpeg", "jpg")                                // everything else → JPEG
    }
}

