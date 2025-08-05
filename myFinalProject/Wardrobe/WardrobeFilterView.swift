//
//  WardrobeFilterView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
//


import SwiftUI

struct WardrobeFilterView: View {
    @Environment(\.presentationMode) private var presentationMode

    // Add any @State or @Binding properties here for your filter criteria,
    // e.g. @State private var selectedSeasons: Set<String> = []

    var body: some View {
        NavigationView {
            Form {
                // Example filter section
                Section(header: Text("Season")) {
                    // Replace with your actual filter controls
                    Toggle("Spring", isOn: .constant(true))
                    Toggle("Summer", isOn: .constant(false))
                    Toggle("Autumn", isOn: .constant(false))
                    Toggle("Winter", isOn: .constant(true))
                }

                // Add more Sections for style, size, color, etc.
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        // Persist/apply your filter selections here
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct WardrobeFilterView_Previews: PreviewProvider {
    static var previews: some View {
        WardrobeFilterView()
    }
}
