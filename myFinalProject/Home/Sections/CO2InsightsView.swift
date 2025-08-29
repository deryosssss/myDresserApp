//
//  CO2InsightsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 22/08/2025.
//  Updated: 26/08/2025 — interactive controls + “CO₂ saved” wording + opaque purple tooltip
//

import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

/// CO₂ insights screen combining charts, stats, and controls to help users explore their environmental impact.
/// - Interactions: range/metric/cumulative toggles + bar selection
/// - Stats: this range, this month, MoM delta
/// - Tools: adjust assumptions, export CSV
///
struct CO2InsightsView: View {

    // MARK: Model

    private struct Point: Identifiable, Hashable {
        let id = UUID()
        let monthStart: Date
        let count: Int
        let kg: Double
    }

    let outfits: [Outfit]
    let factor: Double

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CO2SettingsStore

    // MARK: Controls
    enum Metric: String, CaseIterable, Identifiable { case co2 = "CO₂", outfits = "Outfits"; var id: String { rawValue } }

    @State private var monthsBack: Int = 12
    @State private var metric: Metric = .co2
    @State private var cumulative: Bool = false
    @State private var selectedMonth: Date? = nil
    @State private var showAssumptions = false

    // MARK: Derived series
    private var months: [Date] {
        let cal = Calendar.current
        let now = Date()
        return (0..<monthsBack).reversed().compactMap { offset in
            let d = cal.date(byAdding: .month, value: -offset, to: now) ?? now
            return cal.date(from: cal.dateComponents([.year, .month], from: d))
        }
    }

    private var groupedCounts: [Date: Int] {
        let cal = Calendar.current
        return Dictionary(grouping: outfits) { o -> Date in
            let d = o.createdAt ?? .distantPast
            return cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? .distantPast
        }.mapValues(\.count)
    }

    private var points: [Point] {
        months.map { m in
            let c = groupedCounts[m] ?? 0
            return Point(monthStart: m, count: c, kg: Double(c) * factor)
        }
    }

    private var yLabel: String { metric == .co2 ? "kg CO₂ saved" : "Outfits" }
    private var series: [Double] { points.map { metric == .co2 ? $0.kg : Double($0.count) } }

    private var cumulativeSeries: [Double] {
        var running: [Double] = []
        var acc: Double = 0
        for v in series { acc += v; running.append(acc) }
        return running
    }

    private var plottedSeries: [Double] { cumulative ? cumulativeSeries : series }

    private var totalInRange: Double { series.reduce(0,+) }
    private var thisMonth: Double { series.last ?? 0 }
    private var previousMonth: Double { series.dropLast().last ?? 0 }
    private var momDelta: Double { thisMonth - previousMonth }

    private func monthLabel(_ d: Date) -> String {
        d.formatted(.dateTime.month(.abbreviated))
    }

    // MARK: Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    controls
                    summary
                    chartCard
                    actions
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
        .sheet(isPresented: $showAssumptions) {
            CO2AssumptionsEditor().environmentObject(store)
        }
    }

    // MARK: UI pieces
    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Range", selection: $monthsBack) {
                Text("3m").tag(3)
                Text("6m").tag(6)
                Text("12m").tag(12)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Toggle("Cumulative", isOn: $cumulative)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Cumulative")
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This month")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(formattedValue(thisMonth))
                        .font(AppFont.spicyRice(size: 22)).foregroundColor(.black)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last \(monthsBack) months")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(formattedValue(totalInRange))
                        .font(AppFont.spicyRice(size: 22)).foregroundColor(.black)
                }
            }

            // MoM delta pill
            HStack {
                let up = momDelta >= 0
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.caption).bold()
                Text("\(up ? "+" : "−")\(formattedValue(abs(momDelta))) vs last month")
                    .font(.footnote)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background((momDelta >= 0 ? Color.green.opacity(0.15) : Color.blue.opacity(0.15)))
            .clipShape(Capsule())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandYellow.opacity(0.6))
        )
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(Array(zip(points, plottedSeries)), id: \.0.id) { p, y in
                    BarMark(
                        x: .value("Month", p.monthStart, unit: .month),
                        y: .value(yLabel, y)
                    )
                    .foregroundStyle(barStyle(for: p.monthStart))
                }

                if let sel = selectedMonth,
                   let idx = months.firstIndex(of: sel),
                   idx < plottedSeries.count {
                    let y = plottedSeries[idx]
                    RuleMark(x: .value("Selected", sel))
                        .lineStyle(.init(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .center) {
                            // Opaque purple bubble + pointer
                            VStack(spacing: 0) {
                                Text("\(monthLabel(sel)) • \(formattedValue(y))")
                                    .font(.caption).bold()
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.brandBlue) // fully opaque
                                    )
                                    .accessibilityLabel("\(monthLabel(sel)), \(formattedValue(y))")
                                PointerDown()
                                    .fill(Color.brandBlue)
                                    .frame(width: 12, height: 6)
                                    .offset(y: -1)
                            }
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: monthsBack > 6 ? 2 : 1)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxisLabel(position: .trailing) { Text(yLabel).font(.caption) }
            .frame(height: 260)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let x = value.location.x - origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedMonth = snappedMonthStart(from: date)
                                        hapticLight()
                                    }
                                }
                        )
                }
            }

            if let sel = selectedMonth,
               let p = points.first(where: { $0.monthStart == sel }) {
                HStack {
                    Text("Selected • \(monthLabel(sel))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if metric == .co2 {
                        Text("\(String(format: "%.1f", p.kg)) kg CO₂ saved")
                    } else {
                        Text("\(p.count) outfits")
                    }
                }
                .font(.footnote)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                showAssumptions = true
            } label: {
                Label("Adjust assumptions", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Button {
                copyCSVToPasteboard()
            } label: {
                Label("Copy CSV", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Copies the visible data as CSV")
        }
    }

    private var explainer: some View {
        HomeSectionCard(title: "How we estimate") {
            Text("""
            Your estimate uses \(factor, specifier: "%.1f") kg CO₂ per outfit (set in CO₂ assumptions). \
            Toggle CO₂/Outfits, choose 3/6/12 months, tap bars to inspect, \
            or switch Cumulative for a running total. Trends compare to last month. \
            All CO₂ numbers shown are saved by re-wearing.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers

    private func formattedValue(_ v: Double) -> String {
        switch metric {
        case .co2: return String(format: "%.1f kg CO₂ saved", v)
        case .outfits:
            let i = Int(round(v))
            return "\(i) outfits"
        }
    }

    private func snappedMonthStart(from date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private func barStyle(for month: Date) -> some ShapeStyle {
        guard let sel = selectedMonth else { return Color.accentColor }
        return month == sel ? Color.accentColor : Color.accentColor.opacity(0.45)
    }

    private func copyCSVToPasteboard() {
        let header = metric == .co2 ? "kg_co2_saved" : "outfits"
        var rows = ["month,\(header)"]
        for (i, m) in months.enumerated() {
            let val = plottedSeries[safe: i] ?? 0
            let key = m.formatted(.dateTime.year().month(.twoDigits))
            rows.append("\(key),\(String(format: "%.3f", val))")
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = rows.joined(separator: "\n")
        #endif
    }

    private func hapticLight() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Tiny pointer shape for the callout bubble
private struct PointerDown: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// Small safe index helper
private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
