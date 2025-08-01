//
//  myFinalProjectApp.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI
import FirebaseCore
import Firebase




@main
struct myFinalProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var taggingVM = ImageTaggingViewModel()
    
    var body: some Scene {
        WindowGroup {
//            TaggedItemPreviewView(
//                    originalImage: UIImage(named: "placeholder")!,
//                    taggingVM: taggingVM,
//                    onSave: { /* persist and maybe dismiss or navigate */ },
//                    onDelete: { /* clear and maybe pop back */ }
//                  )
            MainTabView()


        }
    }
}
