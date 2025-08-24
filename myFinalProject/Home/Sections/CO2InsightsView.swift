//
//  CO2InsightsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 22/08/2025.
//  Updated: 22/08/2025 – factor injected from user assumptions.
//

import SwiftUI
import Charts

/// Detailed CO₂ insights:
/// - 12-month bar chart of estimated CO₂ saved (**factor kg per outfit**)
/// - Totals and a short explainer
struct CO2InsightsView: View {
    private struct Point: Identifiable {
        let id = UUID()
        let monthStart: Date
        let kg: Double
    }

    let outfits: [Outfit]
    let factor: Double

    @Environment(\.dismiss) private var dismiss

    private var points: [Point] {
        let cal = Calendar.current
        let now = Date()
        let months: [Date] = (0..<12).reversed().compactMap { offset in
            let d = cal.date(byAdding: .month, value: -offset, to: now) ?? now
            return cal.date(from: cal.dateComponents([.year, .month], from: d))
        }
        let grouped = Dictionary(grouping: outfits) { o -> Date in
            let d = o.createdAt ?? .distantPast
            return cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? .distantPast
        }
        return months.map { m in
            let count = grouped[m]?.count ?? 0
            return Point(monthStart: m, kg: Double(count) * factor)
        }
    }

    private var total12m: Double { points.map(\.kg).reduce(0, +) }
    private var thisMonth: Double { points.last?.kg ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary

                    Chart(points) {
                        BarMark(
                            x: .value("Month", $0.monthStart, unit: .month),
                            y: .value("kg CO₂", $0.kg)
                        )
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                    .frame(height: 240)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    explainer
                }
                .padding(16)
                .navigationTitle("CO₂ insights")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("This month")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg CO₂", thisMonth))
                        .font(AppFont.spicyRice(size: 22)).foregroundColor(.black)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Last 12 months")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg CO₂", total12m))
                        .font(AppFont.spicyRice(size: 22)).foregroundColor(.black)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandYellow.opacity(0.6))
            )
        }
    }

    private var explainer: some View {
        HomeSectionCard(title: "How we estimate") {
            Text("""
            Your estimate uses **\(factor, specifier: "%.1f") kg CO₂ per outfit** (set in CO₂ assumptions). \
            This is meant to be *directional*, not precise.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}
