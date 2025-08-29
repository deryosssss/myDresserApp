// CropImageView.swift
// myFinalProject
//
//  Created by Derya Baglan on 31/07/2025
//
//  1) Shows an image full-screen with a draggable/resizable crop rectangle over a dimmed overlay.
//  2) Lets you resize from any corner (bounded + min size), then "Done" crops and returns the PNG/JPEG.
//  3) Has Reset (restore default crop), Cancel (return original), and a caution banner at the top.
//

import SwiftUI
import UIKit

struct CropImageView: View {
    let image: UIImage                      // input image to crop
    var onComplete: (UIImage) -> Void       // callback with final (or original on cancel)

    @State private var cropRect: CGRect = .zero      // live crop rect in view coordinates
    @State private var startCropRect: CGRect = .zero // crop rect snapshot at gesture start
    @GestureState private var dragOffset: CGSize = .zero // unused (kept if adding drag-to-move)

    // Banner state
    @State private var showBanner = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background image (letterboxed to fit)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(Color.black)
                    .clipped()
                    .aid("crop.image")

                // Dim everything except the crop rect using a path subtraction mask
                Color.black.opacity(0.4)
                    .mask(
                        Rectangle().path(in: CGRect(origin: .zero, size: geo.size))
                            .subtracting(Rectangle().path(in: cropRect))
                    )

                // Visible crop border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)

                // Four draggable corner handles
                ForEach(Corner.allCases, id: \.self) { corner in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 26, height: 26)
                        .shadow(radius: 1, y: 1)
                        .position(handlePosition(for: corner))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if startCropRect == .zero { startCropRect = cropRect } // lock baseline on first move
                                    resizeCropRect(corner: corner, translation: value.translation, in: geo.size)
                                }
                                .onEnded { _ in startCropRect = cropRect } // persist new baseline
                        )
                        .aid(handleId(for: corner))
                }

                // Controls stack (kept below banner when visible)
                VStack(spacing: 10) {
                    Spacer(minLength: showBanner ? 58 : 0) // avoid overlapping the banner

                    HStack {
                        Button("Cancel") { onComplete(image) } // return original
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.98))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(.black)
                            .aid("crop.cancel")

                        Spacer()

                        Button("Reset") {                       // reset to a generous inset rect
                            cropRect = CGRect(
                                x: 50, y: 150,
                                width: geo.size.width - 100,
                                height: geo.size.height - 300
                            )
                            startCropRect = cropRect
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.black)
                        .aid("crop.reset")
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button("Done") {                            // crop using geometry → image pixel space
                        let final = cropUIImage(from: image, in: cropRect, container: geo.frame(in: .local))
                        onComplete(final)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.black)
                    .shadow(radius: 1, y: 1)
                    .padding(.bottom, 20)
                    .aid("crop.done")
                }
            }
            // Prominent safety/UX banner pinned to the top
            .overlay(alignment: .top) {
                if showBanner {
                    WarningBanner(
                        text: "Crop to clothing only — avoid faces and try to minimise visible skin.",
                        onClose: { withAnimation(.easeInOut(duration: 0.25)) { showBanner = false } }
                    )
                    .padding(.top, geo.safeAreaInsets.top + 6)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .aid("crop.banner")
                }
            }
            .onAppear {
                // Initial crop rectangle (inset defaults)
                cropRect = CGRect(
                    x: 50, y: 150,
                    width: geo.size.width - 100,
                    height: geo.size.height - 300
                )
                startCropRect = cropRect
            }
        }
    }

    // Which handle is being dragged
    enum Corner: CaseIterable { case topLeft, topRight, bottomRight, bottomLeft }

    // Convert a corner enum into its current on-screen position
    private func handlePosition(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft:     return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:    return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:  return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight: return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    private func handleId(for corner: Corner) -> String {
        switch corner {
        case .topLeft: return "crop.handle.topLeft"
        case .topRight: return "crop.handle.topRight"
        case .bottomRight: return "crop.handle.bottomRight"
        case .bottomLeft: return "crop.handle.bottomLeft"
        }
    }

    // Resize the crop rect from a specific corner; clamp to bounds + min size
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

        // Enforce min size & keep entirely inside the view
        r.size.width  = max(50, r.size.width)
        r.size.height = max(50, r.size.height)
        r.origin.x    = min(max(0, r.origin.x), bounds.width  - r.size.width)
        r.origin.y    = min(max(0, r.origin.y), bounds.height - r.size.height)
        cropRect = r
    }

    // Convert the cropRect from view space to image pixel space and crop the CGImage
    private func cropUIImage(from uiImage: UIImage, in rect: CGRect, container: CGRect) -> UIImage {
        guard let cg = uiImage.cgImage else { return uiImage }
        let scaleX = CGFloat(cg.width)  / container.width   // pixels per point horizontally
        let scaleY = CGFloat(cg.height) / container.height  // pixels per point vertically
        let cropInPixels = CGRect(
            x: (rect.origin.x - container.minX) * scaleX,
            y: (rect.origin.y - container.minY) * scaleY,
            width: rect.width  * scaleX,
            height: rect.height * scaleY
        ).integral                                         // align to whole pixels for CG
        guard let croppedCg = cg.cropping(to: cropInPixels) else { return uiImage }
        return UIImage(cgImage: croppedCg, scale: uiImage.scale, orientation: uiImage.imageOrientation)
    }
}

// MARK: - Banner

private struct WarningBanner: View {
    let text: String
    var onClose: () -> Void

    @State private var appear = false
    @State private var pulse = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").imageScale(.large)
            Text(text)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .foregroundColor(.black)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.brandYellow)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.brandOrange.opacity(pulse ? 1 : 0.5), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        .scaleEffect(appear ? 1 : 0.95)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appear = true } // entrance
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } // subtle pulse
        }
        .accessibilityLabel("Important: Crop to clothing only. Avoid faces and minimise visible skin.")
    }
}
