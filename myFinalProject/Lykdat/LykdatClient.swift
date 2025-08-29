//
//  LykdatClient.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import Foundation
import UIKit

// MARK: - Response Models
// These Codable structs mirror Lykdat's JSON so we can decode strongly-typed results.
// Keeping models local to this client keeps the API surface small and focused.

/// Item-detection endpoint response:
/// returns detected fashion items and their normalized bounding boxes (0–1 coordinates).
struct ItemDetectionResponse: Codable {

  struct DetectedItem: Codable {
    let name: String              // model's friendly name (e.g., "T-shirt")
    let category: String          // higher-level class (e.g., "top")
    let confidence: Double        // 0..1 confidence score
    let bounding_box: BoundingBox // normalized rect in image space
  }

  struct BoundingBox: Codable {
    let left: Double              // x_min (0..1)
    let top: Double               // y_min (0..1)
    let right: Double             // x_max (0..1)
    let bottom: Double            // y_max (0..1)

    /// Convenience computed sizes; avoids repeating right-left / bottom-top math.
    var width: Double  { right  - left }
    var height: Double { bottom - top  }
  }

  struct DataWrapper: Codable {
    let detected_items: [DetectedItem] // API nests fields under "data"
  }

  let data: DataWrapper
}

/// Deep-tagging endpoint response:
/// dominant colors + item classes + descriptive labels with confidences.
struct DeepTaggingResponse: Codable {

  struct Color: Codable {
    let name: String       // e.g., "navy"
    let hex_code: String   // e.g., "#001f3f"
    let confidence: Double // 0..1
  }

  struct Item: Codable {
    let name: String
    let category: String
    let confidence: Double
  }

  struct Label: Codable {
    let name: String
    let classification: String             // primary group for the label
    let secondary_classification: String?  // optional subgroup
    let confidence: Double
  }

  struct DataWrapper: Codable {
    let colors: [Color]
    let items: [Item]
    let labels: [Label]
  }

  let data: DataWrapper
}

// MARK: - LykdatClient
// Small, focused HTTP client that builds a multipart/form-data request for a JPEG,
// hits two endpoints, and decodes JSON into the models above.
// API key is loaded from Info.plist to keep secrets out of source.

/// Minimal client for Lykdat Cloud API.
/// Note: this uses completion handlers and returns on a background thread; callers who update UI must hop to main.
class LykdatClient {

  // Load API key from Info.plist early; crash loudly if misconfigured.
  // Rationale: failing fast during development surfaces missing keys immediately.
  private let apiKey: String = {
    guard let key = Bundle.main.infoDictionary?["LykdatAPIKey"] as? String,
          !key.isEmpty
    else {
      fatalError("🔑 LykdatAPIKey missing in Info.plist")
    }
    return key
  }()

  // Unique boundary per client instance; safe for concurrent requests.
  private let boundary = UUID().uuidString

  /// Builds a multipart/form-data POST containing a single JPEG part named "image".
  /// Separate builder keeps request creation testable and reusable.
  private func makeRequest(urlString: String, imageData: Data) throws -> URLRequest {
    guard let url = URL(string: urlString) else {
      throw URLError(.badURL) // early, explicit failure for malformed endpoint
    }

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(apiKey, forHTTPHeaderField: "x-api-key") // Lykdat expects API key header
    req.setValue("multipart/form-data; boundary=\(boundary)",
                 forHTTPHeaderField: "Content-Type")

    // Build the multipart body manually for full control (no extra dependencies).
    var body = Data()
    body.append(contentsOf: "--\(boundary)\r\n".utf8)
    body.append(contentsOf:
      "Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n"
        .utf8
    )
    body.append(contentsOf: "Content-Type: image/jpeg\r\n\r\n".utf8)
    body.append(imageData)
    body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)

    req.httpBody = body
    return req
  }

  // MARK: - Public API
  /// Calls the item-detection endpoint; returns an array of detected items (name, category, box, confidence).
  /// Errors: network failures, invalid JSON, or non-data responses bubble up via Result.
  func detectItems(
    imageData: Data,
    completion: @escaping (Result<[ItemDetectionResponse.DetectedItem], Error>) -> Void
  ) {
    do {
      let req = try makeRequest(
        urlString: "https://cloudapi.lykdat.com/v1/detection/items",
        imageData: imageData
      )

      URLSession.shared.dataTask(with: req) { data, response, err in
        // Propagate transport error first.
        if let err = err {
          return completion(.failure(err))
        }

        // Optional improvement: check HTTP status codes.
        // If desired, cast response to HTTPURLResponse and guard 200..<300.

        guard let data = data else {
          return completion(.failure(NSError(
            domain: "Lykdat", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "No data received"]
          )))
        }

        do {
          // Decode into our typed response and return the inner payload.
          let resp = try JSONDecoder().decode(ItemDetectionResponse.self, from: data)
          completion(.success(resp.data.detected_items))
        } catch {
          completion(.failure(error)) // JSON mismatch or schema drift
        }
      }
      .resume()
    } catch {
      completion(.failure(error)) // request build issues (e.g., bad URL)
    }
  }

  /// Calls the deep-tagging endpoint; returns colors, items, and labels in one struct.
  /// Mirrors detectItems for consistency and easy call-site swapping.
  func deepTags(
    imageData: Data,
    completion: @escaping (Result<DeepTaggingResponse.DataWrapper, Error>) -> Void
  ) {
    do {
      let req = try makeRequest(
        urlString: "https://cloudapi.lykdat.com/v1/detection/tags",
        imageData: imageData
      )

      URLSession.shared.dataTask(with: req) { data, response, err in
        if let err = err {
          return completion(.failure(err))
        }

        guard let data = data else {
          return completion(.failure(NSError(
            domain: "Lykdat", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "No data received"]
          )))
        }

        do {
          let resp = try JSONDecoder().decode(DeepTaggingResponse.self, from: data)
          completion(.success(resp.data))
        } catch {
          completion(.failure(error))
        }
      }
      .resume()
    } catch {
      completion(.failure(error))
    }
  }
}
