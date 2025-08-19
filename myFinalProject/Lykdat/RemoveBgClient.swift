//
//  RemoveBgClient.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//


import Foundation
import UIKit

/// Thin wrapper around the remove.bg REST API.
/// Sends an image, receives a background-removed PNG (cutout).
///
///Loads RemoveBgAPIKey from Info.plist, builds a multipart/form-data POST to https://api.remove.bg/v1.0/removebg with the image as image_file, and returns the background-removed PNG via a completion handler.
///
class RemoveBgClient: ObservableObject {
    private let apiKey: String = {
        guard let key = Bundle.main
              .infoDictionary?["RemoveBgAPIKey"] as? String,
              !key.isEmpty
        else {
            fatalError("🔑 RemoveBgAPIKey missing in Info.plist")
        }
        return key
    }()
    private let boundary = UUID().uuidString

    /// Sends the image to remove.bg and returns the cutout (PNG)
    func removeBackground(
        from image: UIImage,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        guard let imageData = image.pngData() else {
            completion(.failure(NSError(
                domain: "RemoveBg", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"]
            )))
            return
        }

        var req = URLRequest(url: URL(string: "https://api.remove.bg/v1.0/removebg")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        // build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
          "Content-Disposition: form-data; name=\"image_file\"; filename=\"image.png\"\r\n"
            .data(using: .utf8)!
        )
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, _, err in
            if let err = err {
                completion(.failure(err)); return
            }
            guard let data = data,
                  let cutout = UIImage(data: data)
            else {
                completion(.failure(NSError(
                    domain: "RemoveBg", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No cutout returned"]
                )))
                return
            }
            completion(.success(cutout))
        }.resume()
    }
}
