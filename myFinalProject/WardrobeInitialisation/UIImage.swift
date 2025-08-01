//
//  UIImage.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import UIKit

extension UIImage {
  func cropped(toNormalized normRect: CGRect) -> UIImage? {
    guard let cg = cgImage else { return nil }
    let pxW = CGFloat(cg.width)
    let pxH = CGFloat(cg.height)
    let cropPx = CGRect(
      x: normRect.origin.x * pxW,
      y: normRect.origin.y * pxH,
      width: normRect.size.width  * pxW,
      height: normRect.size.height * pxH
    ).integral

    guard let cropped = cg.cropping(to: cropPx) else { return nil }
    return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
  }
}
