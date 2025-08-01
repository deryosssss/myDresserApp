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

  /// The full original image the user picked or shot
  let originalImage: UIImage

  /// Your VM that publishes `detectedItems` & `deepTags`
  @ObservedObject var taggingVM: ImageTaggingViewModel

  /// Called when “Save” is tapped
  var onSave: () -> Void

  /// Called when “Delete” is tapped
  var onDelete: () -> Void

  // MARK: — State

  /// The image we actually display (cropped once detection arrives)
  @State private var displayImage: UIImage

  // MARK: — Layout

  /// adaptive grid for tag chips
  private let chipColumns = [ GridItem(.adaptive(minimum: 80), spacing: 8) ]

  // MARK: — Init

  init(
    originalImage: UIImage,
    taggingVM: ImageTaggingViewModel,
    onSave: @escaping () -> Void,
    onDelete: @escaping () -> Void
  ) {
    self.originalImage = originalImage
    self._displayImage = State(initialValue: originalImage)
    self.taggingVM = taggingVM
    self.onSave = onSave
    self.onDelete = onDelete
  }

  // MARK: — Body

  var body: some View {
    VStack(spacing: 16) {
      // — Loading / Error
      if taggingVM.isLoading {
        ProgressView("Tagging…")
          .frame(maxWidth: .infinity)
          .padding()
      }
      if let error = taggingVM.errorMessage {
        Text(error)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      // — Image + overlay buttons
      ZStack(alignment: .topTrailing) {
        Image(uiImage: displayImage)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          .background(Color(white: 0.95))
          .cornerRadius(8)

        HStack(spacing: 12) {
          Button(action: onDelete) {
            Image(systemName: "trash.circle.fill")
              .font(.system(size: 28))
              .foregroundColor(.red)
              .background(Color.white)
              .clipShape(Circle())
          }
          Button(action: {}) {
            Image(systemName: "ellipsis.circle.fill")
              .font(.system(size: 28))
              .foregroundColor(.primary)
              .background(Color.white)
              .clipShape(Circle())
          }
        }
        .padding(12)
      }
      .padding(.horizontal)

      // — Tag lists
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if !taggingVM.detectedItems.isEmpty {
            Text("Items Detected")
              .font(.headline)
              .padding(.horizontal)

            LazyVGrid(columns: chipColumns, spacing: 8) {
              ForEach(taggingVM.detectedItems, id: \.name) { item in
                Text(item.name.capitalized)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.blue.opacity(0.2))
                  .cornerRadius(8)
              }
            }
            .padding(.horizontal)
          }

          if let colors = taggingVM.deepTags?.colors, !colors.isEmpty {
            Text("Colors")
              .font(.headline)
              .padding(.horizontal)

            LazyVGrid(columns: chipColumns, spacing: 8) {
              ForEach(colors, id: \.name) { c in
                Text(c.name.capitalized)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.yellow.opacity(0.2))
                  .cornerRadius(8)
              }
            }
            .padding(.horizontal)
          }

          if let labels = taggingVM.deepTags?.labels, !labels.isEmpty {
            Text("Labels")
              .font(.headline)
              .padding(.horizontal)

            LazyVGrid(columns: chipColumns, spacing: 8) {
              ForEach(labels, id: \.name) { lbl in
                Text(lbl.name.capitalized)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.gray.opacity(0.2))
                  .cornerRadius(8)
              }
            }
            .padding(.horizontal)
          }
        }
      }

      // — Save / Delete buttons
      HStack(spacing: 20) {
        Button(action: onDelete) {
          Text("Delete")
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        Button(action: onSave) {
          Text("Save")
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
      }
      .padding([.horizontal, .bottom])
    }
    .background(Color.white)
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

    // — when we get new detections, crop to the first box
    .onReceive(taggingVM.$detectedItems) { items in
      guard let first = items.first else { return }

      // build normalized CGRect from your BoundingBox
      let bbox = first.bounding_box
      let normRect = CGRect(
        x: bbox.left,
        y: bbox.top,
        width: bbox.width,
        height: bbox.height
      )

      if let cropped = originalImage.cropped(toNormalized: normRect) {
        displayImage = cropped
      }
    }
  }
}


