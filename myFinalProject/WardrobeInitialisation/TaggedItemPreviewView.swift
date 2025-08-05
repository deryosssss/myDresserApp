//
//  TaggedItemPreviewView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//
//

import SwiftUI
import UIKit

// MARK: — Color Helpers

extension Color {
    /// Initialize from hex string (e.g. "#ff0000" or "ff0000").
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >>  8) & 0xFF) / 255
        let b = Double((v >>  0) & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
    /// Compute luminance to choose white/black text.
    static func isDark(hex: String) -> Bool {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return false }
        let r = Double((v >> 16) & 0xFF)
        let g = Double((v >>  8) & 0xFF)
        let b = Double((v >>  0) & 0xFF)
        let lum = (0.299*r + 0.587*g + 0.114*b) / 255
        return lum < 0.5
    }
}

struct TaggedItemPreviewView: View {
    // MARK: Inputs
    let originalImage: UIImage
    @ObservedObject var taggingVM: ImageTaggingViewModel
    var onDismiss: () -> Void    // call to dismiss sheet
    
    // MARK: State for editing
    @State private var editingField: EditableField?
    @State private var draftText: String = ""
    
    // MARK: — Which field is being edited?
    enum EditableField: Hashable, Identifiable {
        case category, subcategory, length, style, designPattern
        case closureType, fit, material, dressCode, season, size
        case colours, customTags, moodTags
        var id: Self { self }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // — Title
                Text("Review & Save")
                    .font(AppFont.spicyRice(size: 28))
                    .padding(.top)
                
                // — Image
                Image(uiImage: originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .background(Color(white: 0.93))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // — Colours (inline, no gray box)
                if let colors = taggingVM.deepTags?.colors, !colors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Colours").bold().padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(colors, id: \.name) { tag in
                                    let bg = Color(hex: tag.hex_code) ?? .gray
                                    Text(tag.name.capitalized)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(bg)
                                        .foregroundColor(Color.isDark(hex: tag.hex_code) ? .white : .black)
                                        .cornerRadius(12)
                                }
                                tinyEditButton { editField(.colours) }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // — Auto-generated single-value fields (brandYellow chips)
                chipRow("Category",     text: $taggingVM.category,     field: .category)
                chipRow("Sub Category", text: $taggingVM.subcategory,   field: .subcategory)
                chipRow("Length",       text: $taggingVM.length,        field: .length)
                chipRow("Style",        text: $taggingVM.style,         field: .style)
                chipRow("Design / Pattern", text: $taggingVM.designPattern, field: .designPattern)
                chipRow("Closure",      text: $taggingVM.closureType,   field: .closureType)
                chipRow("Fit",          text: $taggingVM.fit,           field: .fit)
                chipRow("Material",     text: $taggingVM.material,      field: .material)
                
                // — User-added
                chipSection("Custom Tags", chips: taggingVM.tags,      field: .customTags)
                chipRow(    "Dress Code", text: $taggingVM.dressCode,  field: .dressCode)
                chipRow(    "Season",     text: $taggingVM.season,     field: .season)
                chipRow(    "Size",       text: $taggingVM.size,       field: .size)
                chipSection("Mood Tag",    chips: taggingVM.moodTags,  field: .moodTags)
                
                // — Bottom buttons
                HStack(spacing: 12) {
                    Button("Delete") {
                        taggingVM.clearAll()
                        onDismiss()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandPink)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    
                    Button("Save") {
                        taggingVM.uploadAndSave(image: originalImage)
                        onDismiss()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.brandGreen)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        // card styling
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        // edit sheet
        .sheet(item: $editingField) { field in
            editSheet(for: field)
        }
    }
    
    // MARK: Helpers
    
    private func tinyEditButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("✎")
                .font(.caption2)
                .foregroundColor(.blue)
                .padding(6)
        }
        .background(Color.white)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue, lineWidth: 1))
    }
    
    private func chipRow(_ title: String,
                         text: Binding<String>,
                         field: EditableField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).bold().padding(.horizontal)
            HStack {
                let v = text.wrappedValue.trimmingCharacters(in: .whitespaces)
                Text(v.isEmpty ? "None" : v.capitalized)
                    .font(.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray5))
                    .foregroundColor(.black)
                    .cornerRadius(12)
                Spacer()
                tinyEditButton { editField(field) }
            }
            .padding(.horizontal)
        }
    }
    
    private func chipSection(_ title: String,
                             chips: [String],
                             bgColor: Color = Color(.systemGray5),
                             field: EditableField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).bold().padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if chips.isEmpty {
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                            .frame(height: 28)
                    } else {
                        ForEach(chips, id: \.self) { c in
                            Text(c.capitalized)
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(bgColor)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                    tinyEditButton { editField(field) }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func editField(_ field: EditableField) {
        switch field {
        case .category:      draftText = taggingVM.category
        case .subcategory:   draftText = taggingVM.subcategory
        case .length:        draftText = taggingVM.length
        case .style:         draftText = taggingVM.style
        case .designPattern: draftText = taggingVM.designPattern
        case .closureType:   draftText = taggingVM.closureType
        case .fit:           draftText = taggingVM.fit
        case .material:      draftText = taggingVM.material
        case .dressCode:     draftText = taggingVM.dressCode
        case .season:        draftText = taggingVM.season
        case .size:          draftText = taggingVM.size
        default:             draftText = ""
        }
        editingField = field
    }
    
    @ViewBuilder
    private func editSheet(for field: EditableField) -> some View {
        NavigationView {
            Form {
                switch field {
                case .colours, .customTags, .moodTags:
                    Section("Add new") {
                        TextField("Value", text: $draftText)
                    }
                    Section("Existing") {
                        let bind: Binding<[String]> = {
                            switch field {
                            case .colours:    return $taggingVM.colours
                            case .customTags: return $taggingVM.tags
                            case .moodTags:   return $taggingVM.moodTags
                            default: fatalError()
                            }
                        }()
                        ForEach(bind.wrappedValue.indices, id: \.self) { idx in
                            HStack {
                                Text(bind.wrappedValue[idx])
                                Spacer()
                                Button(role: .destructive) {
                                    bind.wrappedValue.remove(at: idx)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                default:
                    Section {
                        TextField(fieldTitle(field), text: $draftText)
                    }
                }
            }
            .navigationTitle(fieldTitle(field))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingField = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let v = draftText.trimmingCharacters(in: .whitespaces)
                        switch field {
                        case .category:      taggingVM.category = v
                        case .subcategory:   taggingVM.subcategory = v
                        case .length:        taggingVM.length = v
                        case .style:         taggingVM.style = v
                        case .designPattern: taggingVM.designPattern = v
                        case .closureType:   taggingVM.closureType = v
                        case .fit:           taggingVM.fit = v
                        case .material:      taggingVM.material = v
                        case .dressCode:     taggingVM.dressCode = v
                        case .season:        taggingVM.season = v
                        case .size:          taggingVM.size = v
                        case .colours where !v.isEmpty:
                            taggingVM.colours.append(v)
                        case .customTags where !v.isEmpty:
                            taggingVM.tags.append(v)
                        case .moodTags where !v.isEmpty:
                            taggingVM.moodTags.append(v)
                        default: break
                        }
                        editingField = nil
                    }
                }
            }
        }
    }
    
    private func fieldTitle(_ field: EditableField) -> String {
        switch field {
        case .colours:       return "Colours"
        case .customTags:    return "Custom Tags"
        case .moodTags:      return "Mood Tags"
        case .category:      return "Category"
        case .subcategory:   return "Sub-Category"
        case .length:        return "Length"
        case .style:         return "Style"
        case .designPattern: return "Design / Pattern"
        case .closureType:   return "Closure"
        case .fit:           return "Fit"
        case .material:      return "Material"
        case .dressCode:     return "Dress Code"
        case .season:        return "Season"
        case .size:          return "Size"
        }
    }
}

#if DEBUG
struct TaggedItemPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ImageTaggingViewModel()
        vm.category = "Dress"
        vm.subcategory = "Evening"
        vm.deepTags = DeepTaggingResponse.DataWrapper(
            colors: [
                .init(name: "French Pink", hex_code: "ff66a3", confidence: 1),
                .init(name: "Pacific Blue", hex_code: "0099ff", confidence: 1)
            ],
            items: [],
            labels: []
        )
        vm.length = "Maxi"
        vm.style = "Elegant"
        vm.designPattern = "Plain"
        vm.closureType = "Zipper"
        vm.fit = "Regular"
        vm.material = "Silk"
        vm.tags = ["Party", "Formal"]
        vm.dressCode = "Black Tie"
        vm.season = "Summer"
        vm.size = "M"
        vm.moodTags = ["Happy", "Confident"]
        
        return TaggedItemPreviewView(
            originalImage: UIImage(systemName: "photo")!,
            taggingVM: vm,
            onDismiss: {}
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif


