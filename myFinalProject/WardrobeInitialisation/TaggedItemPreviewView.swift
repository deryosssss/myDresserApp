//
//  TaggedItemPreviewView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//
//

import SwiftUI
import UIKit

struct TaggedItemPreviewView: View {
  // MARK: — Inputs
  let originalImage: UIImage
  @ObservedObject var taggingVM: ImageTaggingViewModel
  var onSave: () -> Void
  var onDelete: () -> Void

  // MARK: — Layout Helpers

  private func detailRow(
    _ title: String,
    value: String,
    editAction: @escaping () -> Void
  ) -> some View {
    HStack {
      Text(title).bold()
      Spacer()
      Text(value.isEmpty ? "—" : value)
        .foregroundColor(.secondary)
      tinyEditButton(action: editAction)
    }
    .padding()
    .background(Color(white: 0.95))
    .cornerRadius(8)
    .padding(.horizontal)
  }

  private func chipSection(
    _ title: String,
    chips: [String],
    editAction: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).bold()
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(chips, id: \.self) { c in
            Text(c.capitalized)
              .font(.caption)
              .padding(.vertical, 6)
              .padding(.horizontal, 12)
              .background(Color.brandYellow)
              .cornerRadius(12)
          }
          tinyEditButton(action: editAction)
        }
      }
    }
    .padding()
    .background(Color(white: 0.95))
    .cornerRadius(8)
    .padding(.horizontal)
  }

  private func tinyEditButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text("✎")
        .font(.caption2)
        .foregroundColor(.blue)
        .padding(6)
    }
    .background(Color.white)
    .cornerRadius(6)
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(Color.blue, lineWidth: 1)
    )
  }

  // MARK: — Body

  var body: some View {
    VStack(spacing: 12) {
      // — Title
      Text("Review & Save")
        .font(AppFont.spicyRice(size: 28))
        .padding(.top)
        .frame(maxWidth: .infinity)
      
      // — Image box
      Image(uiImage: originalImage)
        .resizable()
        .scaledToFit()
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.93))
        .cornerRadius(12)
        .padding(.horizontal)
      
      // — Fields list
      ScrollView {
        VStack(spacing: 12) {
          detailRow("Category",     value: taggingVM.category)    { /* edit */ }
          detailRow("Sub Category", value: taggingVM.subcategory) { /* edit */ }

          chipSection("Colours",    chips: taggingVM.colours)      { /* edit colours */ }
          chipSection("Tags",       chips: taggingVM.tags)         { /* edit tags    */ }

          detailRow("Length",     value: taggingVM.length)        { /* edit */ }
          detailRow("Style",      value: taggingVM.style)         { /* edit */ }
          detailRow("Design / Pattern",
                    value: taggingVM.designPattern)             { /* edit */ }
          detailRow("Closure",    value: taggingVM.closureType)   { /* edit */ }
          detailRow("Fit",        value: taggingVM.fit)           { /* edit */ }
          detailRow("Material",   value: taggingVM.material)      { /* edit */ }
          detailRow("Fastening",  value: taggingVM.fastening)     { /* edit */ }
          detailRow("Dress Code", value: taggingVM.dressCode)     { /* edit */ }
          detailRow("Season",     value: taggingVM.season)        { /* edit */ }
          detailRow("Size",       value: taggingVM.size)          { /* edit */ }

          chipSection("Mood Tag", chips: taggingVM.moodTags)      { /* edit mood tags */ }
        }
        .padding(.vertical)
      }

      // — Bottom Delete / Save buttons
      HStack(spacing: 12) {
        Button(action: onDelete) {
          Text("Delete")
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.brandPink)
            .foregroundColor(.black)
            .cornerRadius(8)
        }
        Button(action: onSave) {
          Text("Save")
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.brandGreen)  //
            .foregroundColor(.black)
            .cornerRadius(8)
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 16)
    }
    .background(Color.white)
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
  }
}

// MARK: — Preview

#if DEBUG
struct TaggedItemPreviewView_Previews: PreviewProvider {
  static var previews: some View {
    TaggedItemPreviewView(
      originalImage: UIImage(systemName: "photo")!,
      taggingVM: ImageTaggingViewModel(),
      onSave: {},
      onDelete: {}
    )
    .previewLayout(.sizeThatFits)
    .padding()
  }
}
#endif
