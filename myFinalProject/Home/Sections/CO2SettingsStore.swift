//
//  CO2SettingsStore.swift
//  myFinalProject
//
//  Created by Derya Baglan on 22/08/2025.
//

import SwiftUI

/// User-tweakable assumptions driving CO₂ estimates.
/// Values are persisted with `@AppStorage` and exposed via an ObservableObject
/// so the UI updates live when the user tweaks them.
final class CO2SettingsStore: ObservableObject {

    enum Mode: String, CaseIterable, Identifiable {
        case simple   // constant kg per outfit
        case advanced // purchase displacement + care energy
        var id: String { rawValue }
    }

    // Persisted fields. We call objectWillChange in didSet to notify subscribers.
    @AppStorage("co2_mode") private var modeRaw: String = Mode.simple.rawValue { didSet { objectWillChange.send() } }
    @AppStorage("co2_simple_per_outfit") var simplePerOutfit: Double = 0.8 { didSet { objectWillChange.send() } }

    // Advanced model knobs
    @AppStorage("co2_displacement") var displacement: Double = 0.30 { didSet { objectWillChange.send() } } // 0..1
    @AppStorage("co2_production_kg") var productionKg: Double = 12.0 { didSet { objectWillChange.send() } } // avg production of a typical garment you might have bought
    @AppStorage("co2_avg_wears") var avgWearsPerPurchase: Double = 30.0 { didSet { objectWillChange.send() } } // avg wears a newly bought garment gets
    @AppStorage("co2_laundry_kg") var laundryKg: Double = 0.30 { didSet { objectWillChange.send() } } // per wear care footprint (wash+dry)

    var mode: Mode {
        get { Mode(rawValue: modeRaw) ?? .simple }
        set { modeRaw = newValue.rawValue }
    }

    /// Derived per-outfit saving (kg CO₂) according to the selected model.
    /// - Simple: a flat constant per outfit.
    /// - Advanced: `displacement * (productionKg / avgWears) - laundryKg`, clamped at 0.
    var estimatedKgPerOutfit: Double {
        switch mode {
        case .simple:
            return max(0, simplePerOutfit)
        case .advanced:
            let avoidedPerWear = displacement * (productionKg / max(avgWearsPerPurchase, 1))
            return max(0, avoidedPerWear - laundryKg)
        }
    }

    func resetDefaults() {
        mode = .simple
        simplePerOutfit = 0.8
        displacement = 0.30
        productionKg = 12.0
        avgWearsPerPurchase = 30.0
        laundryKg = 0.30
    }
}
