//
//  NiceDonutChart.swift
//  myFinalProject
//
//  Updated: non-rounded slice ends (no .round caps)
//
//  - This file renders an interactive donut chart in SwiftUI.
//  - Slices are derived from raw Double "value"s that are normalized to sum to 1.0.
//  - Selecting a slice "explodes" (offsets) it slightly, thickens its stroke, and
//    updates the center label + legend highlight. Tapping again clears selection.

import SwiftUI
import UIKit   // haptics

/// Stable segment model (id = label so colors/selection don't flicker)
struct DonutSegment: Identifiable, Equatable {
    let id: String          // stable identity per label
    let value: Double       // raw weight (will be normalized)
    let label: String
    let color: Color
    let rawCount: Int
}

struct NiceDonutChart: View {
    let segments: [DonutSegment]

    // Appearance
    var height: CGFloat = 240
    var inset: CGFloat = 10
    var legendMin: CGFloat = 132

    // Center label when nothing selected
    var centerTitleWhenNone: String = "All"
    var centerSubtitleWhenNone: String = "Tap a slice"

    // Callback on selection (fires only when selecting, not when clearing)
    var onSelect: ((DonutSegment) -> Void)? = nil

    @State private var selectedID: String?  // keep selection stable by label

    // Normalize values defensively (sum may not be 1)
    private var normalized: [DonutSegment] {
        let sum = max(segments.map(\.value).reduce(0, +), 0.0001)
        return segments.map {
            DonutSegment(
                id: $0.id,
                value: $0.value / sum,
                label: $0.label,
                color: $0.color,
                rawCount: $0.rawCount
            )
        }
    }

    var body: some View {
        let data = normalized

        if data.isEmpty {
            EmptyDonutPlaceholder()
                .frame(height: height)
        } else {
            // If no selection → full circle presentation (no focus)
            let focusIndex: Int? = selectedID.flatMap { sid in data.firstIndex(where: { $0.id == sid }) }
            let focusSeg: DonutSegment? = focusIndex.map { data[$0] }

            VStack(spacing: 12) {
                ZStack {
                    GeometryReader { geo in
                        let size   = min(geo.size.width, geo.size.height) - 2*inset
                        let radius = size / 2
                        let baseW  = size * 0.24
                        let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                        let starts = cumulativeAngles(data)

                        // Track behind segments
                        Circle()
                            .stroke(Color.white.opacity(0.7), lineWidth: baseW * 0.35)
                            .frame(width: radius*2, height: radius*2)
                            .position(center)
                            .blur(radius: 0.2)

                        // Main segments (square ends)
                        ForEach(Array(data.enumerated()), id: \.element.id) { i, seg in
                            let start = starts[i]
                            let end   = start + Angle(degrees: seg.value * 360)
                            let isFocus = (i == focusIndex)

                            let lineW: CGFloat = baseW * (isFocus ? 1.28 : 1.0)
                            let explode: CGFloat = isFocus ? baseW * 0.22 : 0.0

                            // Direction for explode offset (account for -90° rotation later)
                            let midRad = (start.radians + end.radians) / 2 - .pi/2
                            let dx = cos(midRad) * explode
                            let dy = sin(midRad) * explode

                            Circle()
                                .trim(from: CGFloat(start.radians / (2*Double.pi)),
                                      to:   CGFloat(end.radians   / (2*Double.pi)))
                                .stroke(
                                    seg.color.opacity(isFocus ? 1.0 : 0.92),
                                    style: StrokeStyle(
                                        lineWidth: lineW,
                                        lineCap: .butt,        // ⬅️ square ends (no rounding)
                                        lineJoin: .miter
                                    )
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: radius*2, height: radius*2)
                                .position(center)
                                .offset(x: dx, y: dy)
                                .shadow(radius: isFocus ? 3 : 0, y: isFocus ? 1 : 0)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        if selectedID == seg.id {
                                            selectedID = nil
                                        } else {
                                            selectedID = seg.id
                                            onSelect?(seg)
                                        }
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                        }

                        if focusIndex != nil {
                            Circle()
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                .frame(width: radius*2 + baseW*0.16, height: radius*2 + baseW*0.16)
                                .position(center)
                                .blur(radius: 0.6)
                        }
                    }
                    .frame(height: height)
                    .padding(.vertical, 36)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedID)

                    // Center label
                    VStack(spacing: 4) {
                        if let seg = focusSeg {
                            Text(seg.label)
                                .font(AppFont.agdasima(size: 20).weight(.medium))
                            Text("\(Int(round(seg.value * 100)))%")
                                .font(.headline)
                        } else {
                            Text(centerTitleWhenNone)
                                .font(AppFont.agdasima(size: 20).weight(.medium))
                            Text(centerSubtitleWhenNone)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                }

                // Legend (tappable)
                let cols = [GridItem(.adaptive(minimum: legendMin), spacing: 8)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { _, s in
                        let isFocus = (s.id == selectedID)
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                if selectedID == s.id {
                                    selectedID = nil
                                } else {
                                    selectedID = s.id
                                    onSelect?(s)
                                }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(s.color.opacity(isFocus ? 1.0 : 0.92))
                                    .frame(width: 10, height: 10)
                                Text(s.label).font(.caption)
                                Text("• \(s.rawCount)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.95)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isFocus ? Color.brandYellow : Color(.systemGray5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            // If the chosen label disappears from data, clear selection (back to full circle)
            .onChange(of: data.map(\.id)) { _ in
                if let sid = selectedID, !data.contains(where: { $0.id == sid }) {
                    selectedID = nil
                }
            }
        }
    }

    private func cumulativeAngles(_ segs: [DonutSegment]) -> [Angle] {
        var result: [Angle] = []
        var total = 0.0
        for s in segs {
            result.append(.degrees(total * 360))
            total += s.value
        }
        return result
    }
}

private struct EmptyDonutPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 24)
                Text("No data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text("Add a few items to see insights.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
