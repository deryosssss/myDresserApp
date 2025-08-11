//
//  DebugUtilities.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//

import FirebaseStorage

func logBuckets() {
    let defaultBucket = Storage.storage().reference().bucket
    let forcedBucket  = StorageBucket.instance.reference().bucket  // from our helper

    print("🔥 Firebase Storage default bucket:", defaultBucket)
    print("🔥 Firebase Storage forced bucket :", forcedBucket)
}
