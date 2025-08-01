//
//  effects.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
import SwiftUI

extension View {
    func appDropShadow() -> some View {
        self.shadow(color: .black.opacity(1), radius: 6, x: 2, y: 4)
    }
}
