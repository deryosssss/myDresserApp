//
//  MainTabView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//

import SwiftUI

struct MainTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        UITabBar.appearance().unselectedItemTintColor = .black
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Image(systemName: "house.fill"); Text("Home") }

            NavigationStack { AddItemCameraView() }
                .tabItem { Image(systemName: "plus.square"); Text("Add") }

            NavigationStack { MagicView() }
                .tabItem { Image(systemName: "wand.and.stars"); Text("Create") }

            NavigationStack { WardrobeView() }
                .tabItem { Image(systemName: "cabinet.fill"); Text("Wardrobe") }

            NavigationStack { ProfileView() }
                .tabItem { Image(systemName: "person.fill"); Text("Profile") }
        }
        .tint(.pink)
    }
}
