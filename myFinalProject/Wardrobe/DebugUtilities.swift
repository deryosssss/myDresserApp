//
//  DebugUtilities.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//

import FirebaseStorage
/// Quick diagnostic helper to print which Firebase Storage bucket is being used.
/// - Prints the bucket from the default Firebase Storage instance (as configured in GoogleService-Info.plist)
/// - Prints the bucket from your custom `StorageBucket.instance` wrapper (your “forced” bucket)
/// Useful for catching misconfig (e.g., wrong project or region) at runtime.
/// 
func logBuckets() {
    let defaultBucket = Storage.storage().reference().bucket
    let forcedBucket  = StorageBucket.instance.reference().bucket  // from our helper

    print("🔥 Firebase Storage default bucket:", defaultBucket)
    print("🔥 Firebase Storage forced bucket :", forcedBucket)
}
