//
//  ManualSuggestionLayout..swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

/// Shared constants for the Manual Suggestion screen.
enum ManualLayout {
    static let topPadding: CGFloat = 20
    static let boxCorner: CGFloat = 14
    static let buttonHeight: CGFloat = 20
    static let sliderSpacing: CGFloat = 14   // horizontal spacing between cards
}

/// Computed sizing based on how many layers are shown.
struct ManualAdaptiveSize {
    let rowHeight: CGFloat
    let cardWidth: CGFloat
    let sectionSpacing: CGFloat     // tighter vertical spacing between layers
    let emptyBoxHeight: CGFloat

    static func forLayers(_ count: Int) -> ManualAdaptiveSize {
        switch count {
        case ...1: return .init(rowHeight: 240, cardWidth: 190, sectionSpacing: 12, emptyBoxHeight: 210)
        case 2:    return .init(rowHeight: 210, cardWidth: 170, sectionSpacing: 10, emptyBoxHeight: 185)
        case 3:    return .init(rowHeight: 165, cardWidth: 138, sectionSpacing: 8,  emptyBoxHeight: 150)
        case 4:    return .init(rowHeight: 116, cardWidth: 106, sectionSpacing: 6,  emptyBoxHeight: 104)
        case 5:    return .init(rowHeight: 116, cardWidth: 106, sectionSpacing: 6,  emptyBoxHeight: 104)
        case 6:    return .init(rowHeight: 108, cardWidth: 98,  sectionSpacing: 5,  emptyBoxHeight: 96)
        default:   return .init(rowHeight: 100, cardWidth: 92,  sectionSpacing: 5,  emptyBoxHeight: 90)
        }
    }
}
