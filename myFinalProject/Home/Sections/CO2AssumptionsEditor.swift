//
//  CO2AssumptionsEditor.swift
//  myFinalProject
//
//  Created by Derya Baglan on 26/08/2025.
//

import SwiftUI

// settings form where users can configure how CO₂ savings are estimated in the app.
// In Simple mode, users select a fixed “kg CO₂ per outfit” value with a slider.
// In Advanced mode, users adjust multiple assumptions (production emissions, purchase displacement, average wears, laundry impact), and the view displays a calculated CO₂ per outfit estimate.
// This is the first iteration and the formula will change

struct CO2AssumptionsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CO2SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    Picker("Mode", selection: $store.mode) {
                        Text("Simple").tag(CO2SettingsStore.Mode.simple)
                        Text("Advanced").tag(CO2SettingsStore.Mode.advanced)
                    }
                    .pickerStyle(.segmented)
                }

                if store.mode == .simple {
                    Section("Simple assumption") {
                        Slider(value: $store.simplePerOutfit, in: 0...3, step: 0.1) {
                            Text("kg CO₂ / outfit")
                        } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("3") }

                        HStack {
                            Text("Selected")
                            Spacer()
                            Text("\(store.simplePerOutfit, specifier: "%.1f") kg CO₂ / outfit")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section("Advanced inputs") {
                        LabeledContent("Purchase displacement") {
                            Slider(value: $store.displacement, in: 0...1, step: 0.05)
                        }
                        LabeledContent("Production per garment") {
                            HStack {
                                Slider(value: $store.productionKg, in: 2...40, step: 0.5)
                                Text("\(store.productionKg, specifier: "%.1f") kg")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Avg wears per purchase") {
                            HStack {
                                Slider(value: $store.avgWearsPerPurchase, in: 5...100, step: 1)
                                Text("\(Int(store.avgWearsPerPurchase))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Laundry per wear") {
                            HStack {
                                Slider(value: $store.laundryKg, in: 0...2, step: 0.05)
                                Text("\(store.laundryKg, specifier: "%.2f") kg")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Derived") {
                        HStack {
                            Text("Estimated kg / outfit")
                            Spacer()
                            Text("\(store.estimatedKgPerOutfit, specifier: "%.2f") kg CO₂ saved")
                                .font(.headline)
                        }
                        Text("Formula: displacement × (production ÷ avg wears) − laundry, clamped at 0.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        store.resetDefaults()
                    } label: {
                        Label("Restore defaults", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CO₂ assumptions")
                        .font(AppFont.spicyRice(size: 30))
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
