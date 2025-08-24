//
//  CO2AssumptionsSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 22/08/2025.
//  Simplified: calmer layout, presets, and “Typical” hints per field.
//

import SwiftUI

/// Interactive sheet where users can understand and tweak how CO₂ is estimated.
struct CO2AssumptionsSheet: View {
    @ObservedObject var settings: CO2SettingsStore
    @Environment(\.dismiss) private var dismiss

    // “Typical” reference values we show next to each control (not enforced).
    private let typicalPerOutfit: Double = 0.8      // kg
    private let typicalDisplacement: Double = 0.30  // 30%
    private let typicalProductionKg: Double = 12.0  // kg per garment
    private let typicalAvgWears: Double = 30.0      // wears
    private let typicalLaundryKg: Double = 0.30     // kg per wear

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Mode selector card
                    SheetCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Model", selection: Binding(
                                get: { settings.mode },
                                set: { settings.mode = $0 }
                            )) {
                                Text("Simple (per outfit)").tag(CO2SettingsStore.Mode.simple)
                                Text("Advanced (purchase + care)").tag(CO2SettingsStore.Mode.advanced)
                            }
                            .pickerStyle(.segmented)

                            Text(settings.mode == .simple
                                 ? "Quick estimate using one constant per outfit. Easy to reason about."
                                 : "Richer model: counts avoided purchases and laundry energy per wear.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if settings.mode == .simple {
                        // SIMPLE
                        SheetCard(header: "Simple model") {
                            ValueRow(
                                title: "kg CO₂ per outfit",
                                valueText: String(format: "%.1f", settings.simplePerOutfit),
                                hint: "Typical \(String(format: "%.1f", typicalPerOutfit)) kg"
                            ) {
                                Slider(value: $settings.simplePerOutfit, in: 0...2, step: 0.1)
                            }

                            InfoNote("""
                            A single number per outfit. Good as a quick proxy. Typical heuristics range 0.5–1.0 kg depending on laundry and what purchases re-wears might displace.
                            """)
                        }
                    } else {
                        // ADVANCED
                        SheetCard(header: "Presets") {
                            PresetChips(
                                onConservative: {
                                    // Lower displacement, higher laundry
                                    settings.displacement = 0.20
                                    settings.productionKg = 10
                                    settings.avgWearsPerPurchase = 40
                                    settings.laundryKg = 0.50
                                },
                                onTypical: {
                                    settings.displacement = typicalDisplacement
                                    settings.productionKg = typicalProductionKg
                                    settings.avgWearsPerPurchase = typicalAvgWears
                                    settings.laundryKg = typicalLaundryKg
                                },
                                onAmbitious: {
                                    // Higher displacement, slightly higher production, lower laundry
                                    settings.displacement = 0.50
                                    settings.productionKg = 16
                                    settings.avgWearsPerPurchase = 25
                                    settings.laundryKg = 0.25
                                }
                            )
                        }

                        SheetCard(header: "Advanced model") {
                            ValueRow(
                                title: "Purchase displacement",
                                valueText: "\(Int(settings.displacement * 100))%",
                                hint: "Typical \(Int(typicalDisplacement * 100))%"
                            ) {
                                Slider(value: $settings.displacement, in: 0...1, step: 0.05)
                            }

                            Divider().padding(.vertical, 2)

                            StepperRow(
                                title: "Production footprint (kg per garment)",
                                value: $settings.productionKg,
                                range: 2...40,
                                step: 1,
                                hint: "Typical \(Int(typicalProductionKg)) kg"
                            )

                            StepperRow(
                                title: "Average wears per new garment",
                                value: $settings.avgWearsPerPurchase,
                                range: 5...100,
                                step: 1,
                                hint: "Typical \(Int(typicalAvgWears)) wears"
                            )

                            StepperRow(
                                title: "Laundry per wear (kg)",
                                value: $settings.laundryKg,
                                range: 0...2,
                                step: 0.05,
                                hint: "Typical \(String(format: "%.2f", typicalLaundryKg)) kg"
                            )

                            InfoNote("""
                            We estimate saved CO₂ per outfit as:
                            displacement × (production ÷ avg wears) − laundry.

                            • Displacement — how often a re-wear avoids buying something new.
                            • Production — embodied emissions of a typical garment you’d otherwise buy.
                            • Avg wears — how many wears that new item would get across its life.
                            • Laundry — emissions from washing/drying this outfit.

                            We clamp negatives to 0 to stay conservative.
                            """)
                        }
                    }

                    // RESULT
                    SheetCard(header: "Result (per outfit)") {
                        Text("\(settings.estimatedKgPerOutfit, specifier: "%.2f") kg CO₂")
                            .font(AppFont.spicyRice(size: 24))
                            .foregroundColor(.black)
                    }

                    // NOTES (collapsed by default to reduce density)
                    SheetCard {
                        DisclosureGroup("What should I pick?") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• If you’re unsure, tap **Typical**. It fits many day-to-day wardrobes.")
                                Text("• Conservative = safer lower saving (harder on the model).")
                                Text("• Ambitious = assumes your re-wears often replace purchases and you wash efficiently.")
                                Text("This is a directional signal to nudge reuse, not a precise LCA.")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                }
                .padding(16)
            }
            .navigationTitle("CO₂ assumptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset") { settings.resetDefaults() }
                }
            }
        }
    }
}

// MARK: - Reusable pieces

/// Rounded “card” container used across the sheet.
private struct SheetCard<Content: View>: View {
    var header: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let header { Text(header.uppercased()).font(.caption).foregroundStyle(.secondary) }
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }
}

/// A tidy row with a title, value label, “Typical …” hint, and a custom control body.
private struct ValueRow<Control: View>: View {
    let title: String
    let valueText: String
    let hint: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.body)
                Spacer()
                Text(valueText).font(.headline)
            }
            control()
            Text(hint).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// Stepper row with live value + typical hint.
private struct StepperRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.body)
                Spacer()
                Text(valueString(value)).font(.headline)
            }
            HStack {
                Stepper("", value: $value, in: range, step: step).labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(hint).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func valueString(_ v: Double) -> String {
        // choose format based on step granularity
        if step >= 1 { return String(format: "%.0f", v) }
        if step <= 0.05 { return String(format: "%.2f", v) }
        return String(format: "%.1f", v)
    }
}

/// Small muted explanatory block.
private struct InfoNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
    }
}

/// Quick presets to reduce thinking.
private struct PresetChips: View {
    var onConservative: () -> Void
    var onTypical: () -> Void
    var onAmbitious: () -> Void

    var body: some View {
        HStack {
            Chip("Conservative", action: onConservative)
            Chip("Typical", action: onTypical)
            Chip("Ambitious", action: onAmbitious)
        }
    }

    private struct Chip: View {
        let title: String
        let action: () -> Void
        @State private var pressed = false

        init(_ title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }

        var body: some View {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5)))
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(pressed ? 0.98 : 1)
                .onTapGesture { action() }
                .onLongPressGesture(minimumDuration: 0.01, pressing: { p in pressed = p }, perform: {})
        }
    }
}
