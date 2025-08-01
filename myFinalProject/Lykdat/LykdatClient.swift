//
//  LykdatClient.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import Foundation
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — Response Models
// ─────────────────────────────────────────────────────────────────────────────

struct ItemDetectionResponse: Codable {
  struct DetectedItem: Codable {
    let name: String
    let category: String
    let confidence: Double
    let bounding_box: BoundingBox
  }
  struct BoundingBox: Codable {
    let left: Double
    let top: Double
    let right: Double
    let bottom: Double

    /// Normalized width & height
    var width: Double  { right  - left }
    var height: Double { bottom - top  }
  }
  struct DataWrapper: Codable {
    let detected_items: [DetectedItem]
  }
  let data: DataWrapper
}

struct DeepTaggingResponse: Codable {
  struct Color: Codable {
    let name: String
    let hex_code: String
    let confidence: Double
  }
  struct Item: Codable {
    let name: String
    let category: String
    let confidence: Double
  }
  struct Label: Codable {
    let name: String
    let classification: String
    let secondary_classification: String?
    let confidence: Double
  }
  struct DataWrapper: Codable {
    let colors: [Color]
    let items: [Item]
    let labels: [Label]
  }
  let data: DataWrapper
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: — LykdatClient
// ─────────────────────────────────────────────────────────────────────────────

class LykdatClient {
  private let apiKey: String = {
    guard let key = Bundle.main.infoDictionary?["LykdatAPIKey"] as? String,
          !key.isEmpty
    else {
      fatalError("🔑 LykdatAPIKey missing in Info.plist")
    }
    return key
  }()

  private let boundary = UUID().uuidString

  /// Builds a multipart/form-data POST request containing the image JPEG.
  private func makeRequest(urlString: String, imageData: Data) throws -> URLRequest {
    guard let url = URL(string: urlString) else {
      throw URLError(.badURL)
    }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    req.setValue("multipart/form-data; boundary=\(boundary)",
                 forHTTPHeaderField: "Content-Type")

    // build a multipart body
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

  /// Calls the item-detection endpoint and returns an array of DetectedItem.
  func detectItems(
    imageData: Data,
    completion: @escaping (Result<[ItemDetectionResponse.DetectedItem], Error>) -> Void
  ) {
    do {
      let req = try makeRequest(
        urlString: "https://cloudapi.lykdat.com/v1/detection/items",
        imageData: imageData
      )
      URLSession.shared.dataTask(with: req) { data, _, err in
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
          let resp = try JSONDecoder().decode(ItemDetectionResponse.self, from: data)
          completion(.success(resp.data.detected_items))
        } catch {
          completion(.failure(error))
        }
      }
      .resume()
    } catch {
      completion(.failure(error))
    }
  }

  /// Calls the deep-tagging endpoint and returns colors, items & labels.
  func deepTags(
    imageData: Data,
    completion: @escaping (Result<DeepTaggingResponse.DataWrapper, Error>) -> Void
  ) {
    do {
      let req = try makeRequest(
        urlString: "https://cloudapi.lykdat.com/v1/detection/tags",
        imageData: imageData
      )
      URLSession.shared.dataTask(with: req) { data, _, err in
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

