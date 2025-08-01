//
//  WardrobeFirestoreService.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import FirebaseFirestore
import FirebaseCore  

class WardrobeFirestoreService {
  private let collection = "wardrobeItems"

  /// Always grab the Firestore instance *after* FirebaseApp.configure() has run.
  private var db: Firestore {
    // Just in case you somehow end up here too early, configure now.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    return Firestore.firestore()
  }

  func saveWardrobeItem(
    imageURL: String,
    detectedItems: [String],
    colors: [String],
    labels: [String],
    completion: @escaping (Error?) -> Void
  ) {
    let data: [String: Any] = [
      "imageURL": imageURL,
      "detectedItems": detectedItems,
      "colors": colors,
      "labels": labels,
      "addedAt": Timestamp(date: Date())
    ]

    db.collection(collection)
      .addDocument(data: data) { error in
        completion(error)
      }
  }
}
