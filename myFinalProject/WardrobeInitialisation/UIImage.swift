//
//  UIImage.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025
//
//  1) Adds a helper to crop a UIImage using a *normalized* rect (values in 0…1 relative to the image size).
//  2) Converts that normalized rect into pixel coordinates, crops the CGImage, and returns a UIImage preserving scale/orientation.
//

import UIKit

extension UIImage {
  /// Crops the image to a normalized rectangle (x, y, w, h in 0…1 of the image's pixel size).
  /// Assumes `normRect` is within [0,1] range; caller should clamp/validate if needed.
  func cropped(toNormalized normRect: CGRect) -> UIImage? {
    guard let cg = cgImage else { return nil }                          // need underlying CGImage to crop
    let pxW = CGFloat(cg.width)                                         // image width in pixels
    let pxH = CGFloat(cg.height)                                        // image height in pixels

    // Convert normalized (0…1) rect → pixel-space rect; align to whole pixels with .integral.
    let cropPx = CGRect(
      x: normRect.origin.x * pxW,
      y: normRect.origin.y * pxH,
      width:  normRect.size.width  * pxW,
      height: normRect.size.height * pxH
    ).integral

    guard let cropped = cg.cropping(to: cropPx) else { return nil }     // perform pixel crop
    // Re-wrap as UIImage, preserving original scale & orientation for consistent display.
    return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
  }
}
