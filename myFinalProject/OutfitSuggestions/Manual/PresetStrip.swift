//
//  PresetStrip.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

struct PresetStrip: View {
    @Binding var selected: LayerPreset
    var onChange: (LayerPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LayerPreset.allCases) { preset in
                    Button {
                        guard selected != preset else { return }
                        selected = preset
                        onChange(preset)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: preset.icon)
                            Text(preset.shortTitle).lineLimit(1)
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected == preset ? Color(.systemGray5) : Color(.secondarySystemBackground))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
