//
//  Accessibility.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//

import SwiftUI

/// Shorthand to tag elements for UI tests without cluttering your views.
public extension View {
    func aid(_ id: String) -> some View { self.accessibilityIdentifier(id) }
}
