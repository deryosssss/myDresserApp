//
//  FirebaseEmulator.swift
//  myFinalProjectUITests
//
//  Created by Derya Baglan on 24/08/2025.
//

import Foundation
import XCTest

/// Minimal HTTP client for the Firebase Auth Emulator (http://localhost:9099).
final class FirebaseEmulator {
    let host: String, projectId: String
    let session = URLSession(configuration: .ephemeral)

    init(host: String = "http://localhost:9099", projectId: String = "demo-test") {
        self.host = host; self.projectId = projectId
    }

    func createUser(email: String, password: String) async throws {
        let url = URL(string: "\(host)/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake")!
        _ = try await post(url: url, json: ["email": email, "password": password, "returnSecureToken": true])
    }

    func sendVerify(email: String) async throws -> URL {
        let url = URL(string: "\(host)/identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=fake")!
        _ = try await post(url: url, json: ["requestType": "VERIFY_EMAIL", "email": email])
        return try await latestOOB(email: email, type: "VERIFY_EMAIL")
    }

    func sendReset(email: String) async throws -> URL {
        let url = URL(string: "\(host)/identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=fake")!
        _ = try await post(url: url, json: ["requestType": "PASSWORD_RESET", "email": email])
        return try await latestOOB(email: email, type: "PASSWORD_RESET")
    }

    /// Mark the verify-email link as consumed (emulator processes it server-side).
    func consumeVerifyLink(_ link: URL) async throws {
        let (_, resp) = try await session.data(from: link)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<400).contains(code) else {
            throw NSError(domain: "OOB", code: code, userInfo: [NSLocalizedDescriptionKey: "Verify link consumption failed"])
        }
    }

    /// Reset the password using the `oobCode` inside the reset link.
    func resetPassword(using link: URL, to newPassword: String) async throws {
        guard let code = URLComponents(url: link, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "oobCode" })?.value else {
            throw NSError(domain: "OOB", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing oobCode"])
        }
        let url = URL(string: "\(host)/identitytoolkit.googleapis.com/v1/accounts:resetPassword?key=fake")!
        _ = try await post(url: url, json: ["oobCode": code, "newPassword": newPassword])
    }

    // MARK: - Internals

    private func latestOOB(email: String, type: String) async throws -> URL {
        let url = URL(string: "\(host)/emulator/v1/projects/\(projectId)/oobCodes")!
        let (data, _) = try await session.data(from: url)
        struct OOB: Decodable { let oobLink: String; let email: String; let requestType: String }
        let all = try JSONDecoder().decode([OOB].self, from: data).reversed()
        guard let link = all.first(where: { $0.email == email && $0.requestType == type })?.oobLink,
              let u = URL(string: link) else {
            throw XCTSkip("No OOB link for \(email) \(type)")
        }
        return u
    }

    @discardableResult
    private func post(url: URL, json: [String: Any]) async throws -> Data {
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, resp) = try await session.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) { throw NSError(domain: "HTTP", code: code) }
        return data
    }
}
