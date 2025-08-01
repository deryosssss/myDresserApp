//
//  CropImageView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//
import SwiftUI
import UIKit

struct CropImageView: View {
    let image: UIImage
    var onComplete: (UIImage) -> Void

    @State private var cropRect: CGRect = .zero
    @State private var startCropRect: CGRect = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(Color.black)
                    .clipped()

                // Dim overlay + crop rectangle
                Color.black.opacity(0.4)
                    .mask(
                        Rectangle().path(in: CGRect(origin: .zero, size: geo.size))
                            .subtracting(Rectangle().path(in: cropRect))
                    )
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)

                // Draggable handles
                ForEach(Corner.allCases, id: \.self) { corner in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                        .position(handlePosition(for: corner))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if startCropRect == .zero { startCropRect = cropRect }
                                    resizeCropRect(corner: corner, translation: value.translation, in: geo.size)
                                }
                                .onEnded { _ in startCropRect = cropRect }
                        )
                }

                // Top/Bottom controls
                VStack {
                    HStack {
                        Button("Cancel") { onComplete(image) }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                            .foregroundColor(.black)
                        Spacer()
                        Button("Reset") {
                            cropRect = CGRect(
                                x: 50, y: 150,
                                width: geo.size.width - 100,
                                height: geo.size.height - 300
                            )
                            startCropRect = cropRect
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(6)
                        .foregroundColor(.black)
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button("Done") {
                        let final = cropUIImage(from: image, in: cropRect, container: geo.frame(in: .local))
                        onComplete(final)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(6)
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                }
            }
            .onAppear {
                // Initialize crop rectangle
                cropRect = CGRect(
                    x: 50, y: 150,
                    width: geo.size.width - 100,
                    height: geo.size.height - 300
                )
                startCropRect = cropRect
            }
        }
    }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomRight, bottomLeft
    }

    private func handlePosition(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft:     return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:    return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:  return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight: return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    private func resizeCropRect(corner: Corner, translation: CGSize, in bounds: CGSize) {
        var r = startCropRect
        switch corner {
        case .topLeft:
            r.origin.x    += translation.width
            r.origin.y    += translation.height
            r.size.width  -= translation.width
            r.size.height -= translation.height
        case .topRight:
            r.origin.y     += translation.height
            r.size.width   += translation.width
            r.size.height  -= translation.height
        case .bottomLeft:
            r.origin.x    += translation.width
            r.size.width  -= translation.width
            r.size.height += translation.height
        case .bottomRight:
            r.size.width  += translation.width
            r.size.height += translation.height
        }
        // enforce min size & bounds
        r.size.width  = max(50, r.size.width)
        r.size.height = max(50, r.size.height)
        r.origin.x    = min(max(0, r.origin.x), bounds.width - r.size.width)
        r.origin.y    = min(max(0, r.origin.y), bounds.height - r.size.height)
        cropRect = r
    }

    private func cropUIImage(from uiImage: UIImage, in rect: CGRect, container: CGRect) -> UIImage {
        guard let cg = uiImage.cgImage else { return uiImage }
        let scaleX = CGFloat(cg.width)  / container.width
        let scaleY = CGFloat(cg.height) / container.height
        let cropInPixels = CGRect(
            x: (rect.origin.x - container.minX) * scaleX,
            y: (rect.origin.y - container.minY) * scaleY,
            width: rect.width  * scaleX,
            height: rect.height * scaleY
        ).integral
        guard let croppedCg = cg.cropping(to: cropInPixels) else { return uiImage }
        return UIImage(cgImage: croppedCg, scale: uiImage.scale, orientation: uiImage.imageOrientation)
    }
}
