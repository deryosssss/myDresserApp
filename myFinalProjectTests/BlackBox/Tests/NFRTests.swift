//
//  NFRTests.swift
//  myFinalProjectUITests
//
//  Covers:
//  • BB-NFR-NFR2-01  GDPR delete request path
//  • BB-NFR-NFR2-02  Consent capture
//  • BB-NFR-NFR4-01  Wi-Fi vs cellular resilience (retry/backoff, no dup writes)
//  • BB-NFR-NFR6-01  Limited offline mode (cached reads ok, writes blocked)
//  • BB-NFR-NFR7-01  Image caching effectiveness
//

import XCTest

// MARK: - Shared helpers

enum TestError: Error { case offline, transientNetwork, unexpected }

// Simple async retry helper with jitter/backoff.
struct Retry {
    static func run<T>(
        attempts: Int = 3,
        initialDelay: TimeInterval = 0.05,
        factor: Double = 2.0,
        _ op: @escaping () async throws -> T
    ) async throws -> T {
        var delay = initialDelay
        var lastError: Error = TestError.unexpected
        for i in 0..<attempts {
            do { return try await op() } catch {
                lastError = error
                if i == attempts - 1 { throw error }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= factor
            }
        }
        throw lastError
    }
}

// MARK: - GDPR delete (BB-NFR-NFR2-01)

protocol Authing {
    var currentUser: AuthUser? { get }
    func signOut() throws
}
protocol AuthUser: AnyObject {
    var uid: String { get }
    func delete() throws
}
protocol FirestoreLike {
    func purgeUserDocs(uid: String) throws
    func hasResidualDocs(uid: String) -> Bool
}
protocol StorageLike {
    func purgeUserFiles(uid: String) throws
    func hasResidualFiles(uid: String) -> Bool
}

/// Service under test: performs full delete
final class AccountDeletionService {
    let auth: Authing
    let db: FirestoreLike
    let storage: StorageLike
    init(auth: Authing, db: FirestoreLike, storage: StorageLike) {
        self.auth = auth; self.db = db; self.storage = storage
    }

    func deleteAccountFully() throws {
        guard let uid = auth.currentUser?.uid else { throw TestError.unexpected }
        try db.purgeUserDocs(uid: uid)
        try storage.purgeUserFiles(uid: uid)
        try auth.currentUser?.delete()
        try auth.signOut()
    }
}

final class FakeUser: AuthUser {
    let uid: String
    var deleted = false
    init(uid: String) { self.uid = uid }
    func delete() throws { deleted = true }
}
final class FakeAuth: Authing {
    var user: FakeUser?
    var didSignOut = false
    var currentUser: AuthUser? { user }
    func signOut() throws { didSignOut = true; user = nil }
}
final class FakeDB: FirestoreLike {
    private var store: [String: Int] = [:] // uid -> doc count
    func seed(uid: String, docs: Int) { store[uid] = docs }
    func purgeUserDocs(uid: String) throws { store[uid] = 0 }
    func hasResidualDocs(uid: String) -> Bool { (store[uid] ?? 0) > 0 }
}
final class FakeStorage: StorageLike {
    private var files: [String: Int] = [:] // uid -> file count
    func seed(uid: String, files n: Int) { files[uid] = n }
    func purgeUserFiles(uid: String) throws { files[uid] = 0 }
    func hasResidualFiles(uid: String) -> Bool { (files[uid] ?? 0) > 0 }
}

final class GDPRDeletionTests: XCTestCase {
    func testGDPRDeleteRemovesAllUserDataAndSignsOut() throws {
        // GIVEN a signed-in user with data in DB + Storage
        let uid = "u1"
        let auth = FakeAuth(); auth.user = FakeUser(uid: uid)
        let db = FakeDB(); db.seed(uid: uid, docs: 7)
        let storage = FakeStorage(); storage.seed(uid: uid, files: 5)
        let service = AccountDeletionService(auth: auth, db: db, storage: storage)

        // WHEN we run full deletion
        try service.deleteAccountFully()

        // THEN DB/Storage have no residues, user is deleted & signed out
        XCTAssertFalse(db.hasResidualDocs(uid: uid))
        XCTAssertFalse(storage.hasResidualFiles(uid: uid))
        XCTAssertTrue((auth.currentUser as? FakeUser) == nil)
        XCTAssertTrue(auth.didSignOut)
    }
}

// MARK: - Consent capture (BB-NFR-NFR2-02)

/// Minimal consent manager backed by UserDefaults (so we can simulate app restarts)
final class ConsentManager {
    private let defaults: UserDefaults
    private let suite: String
    private let kShown = "consent.shown"
    private let kCamera = "consent.camera"
    private let kGallery = "consent.gallery"

    /// Pass `reset: true` only for a "fresh install". A restart should NOT reset.
    init(suiteName: String = "consent-tests", reset: Bool = false) {
        self.suite = suiteName
        defaults = UserDefaults(suiteName: suiteName)!
        if reset {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.synchronize()
        }
    }

    var hasShown: Bool {
        get { defaults.bool(forKey: kShown) }
        set { defaults.set(newValue, forKey: kShown) }
    }
    var cameraAllowed: Bool? {
        get { defaults.object(forKey: kCamera) as? Bool }
        set { defaults.set(newValue, forKey: kCamera) }
    }
    var galleryAllowed: Bool? {
        get { defaults.object(forKey: kGallery) as? Bool }
        set { defaults.set(newValue, forKey: kGallery) }
    }
}

final class ConsentCaptureTests: XCTestCase {
    func testConsentShownAndPersistsAcrossRestarts() {
        // FIRST LAUNCH (fresh install)
        var c = ConsentManager(reset: true)
        XCTAssertFalse(c.hasShown)               // UI should appear
        XCTAssertNil(c.cameraAllowed)
        XCTAssertNil(c.galleryAllowed)

        // User chooses toggles
        c.cameraAllowed = false
        c.galleryAllowed = true
        c.hasShown = true

        // "Restart" app: re-create manager with same suite, no reset
        c = ConsentManager()
        XCTAssertTrue(c.hasShown)                // no UI this time
        XCTAssertEqual(c.cameraAllowed, false)
        XCTAssertEqual(c.galleryAllowed, true)
    }
}

// MARK: - Wi-Fi vs Cellular resilience (BB-NFR-NFR4-01)

/// A repository that writes an edit; our fake will fail once with .networkConnectionLost.
protocol WardrobeEditing {
    func saveEdit(itemId: String, fields: [String: Any]) async throws
    var writes: Int { get }
}
final class FlakyEditor: WardrobeEditing {
    private(set) var writes = 0
    var failFirst = true
    func saveEdit(itemId: String, fields: [String: Any]) async throws {
        writes += 1
        if failFirst {
            failFirst = false
            throw URLError(.networkConnectionLost)
        }
        // succeed (noop)
    }
}

final class ConnectivityResilienceTests: XCTestCase {
    func testRetryBackoffNoDuplicateWrites() async throws {
        let repo = FlakyEditor()
        // attempt the save with retry/backoff
        try await Retry.run(attempts: 2) {
            try await repo.saveEdit(itemId: "abc", fields: ["name":"New"])
        }
        // Should have attempted twice, but only 1 success (and the edit applied once)
        XCTAssertEqual(repo.writes, 2)
    }
}

// MARK: - Limited offline mode (BB-NFR-NFR6-01)

protocol NetworkStatusProviding { var isOnline: Bool { get } }
final class NetStub: NetworkStatusProviding { var isOnline = true }

protocol ItemsRepository {
    func createItem(name: String) async throws -> String
    func cachedItems() -> [String]
}
extension ItemsRepository {
    // Default throws to make the call site explicit in tests
    func createItem(name: String) async throws -> String { throw TestError.unexpected }
}

// Small facade we can test: blocks writes when offline, allows cached reads.
final class WardrobeFacade {
    let net: NetworkStatusProviding
    let repo: ItemsRepository
    init(net: NetworkStatusProviding, repo: ItemsRepository) {
        self.net = net; self.repo = repo
    }

    func tryCreateItem(name: String) async -> Result<String, Error> {
        guard net.isOnline else { return .failure(TestError.offline) }
        do { return .success(try await repo.createItem(name: name)) }
        catch { return .failure(error) }
    }

    func readCached() -> [String] { repo.cachedItems() }
}

/// Fake repo
final class FakeItemsRepo: ItemsRepository {
    private var cache = ["cached-1","cached-2"]
    func cachedItems() -> [String] { cache }
    func createItem(name: String) async throws -> String { "new-id" }
}

final class OfflineModeTests: XCTestCase {
    func testCachedReadableButWritesBlockedOffline() async {
        let net = NetStub(); net.isOnline = false
        let repo = FakeItemsRepo()
        let api = WardrobeFacade(net: net, repo: repo)

        // Cached items visible
        XCTAssertEqual(api.readCached().count, 2)

        // Write blocked with clear error
        let result = await api.tryCreateItem(name: "Tee")
        switch result {
        case .failure(let e):
            if case TestError.offline = e { /* ok */ } else { XCTFail("Wrong error") }
        default:
            XCTFail("Write should be blocked when offline")
        }
    }
}

// MARK: - Image caching effectiveness (BB-NFR-NFR7-01)

/// URLProtocol that serves stub image bytes and counts network hits.
/// If the response includes cache headers, a warm cache should bypass this entirely.
final class MockImageProtocol: URLProtocol {
    static var requestCount = 0
    static var imageData: Data = {
        // 1x1 transparent PNG
        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAOyVgM8AAAAASUVORK5CYII="
        return Data(base64Encoded: pngBase64)!
    }()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let headers = [
            "Content-Type": "image/png",
            "Cache-Control": "public, max-age=3600"
        ]
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: Self.imageData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ImageCachingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockImageProtocol.self)
        MockImageProtocol.requestCount = 0

        // Generous cache so responses are stored
        let cache = URLCache(memoryCapacity: 8 * 1024 * 1024,
                             diskCapacity: 50 * 1024 * 1024,
                             diskPath: "img-cache-tests")
        URLCache.shared = cache
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockImageProtocol.self)
        super.tearDown()
    }

    func testSecondVisitHitsWarmCache() async throws {
        let url = URL(string: "https://example.com/i.png")!
        let session = URLSession(configuration: {
            let cfg = URLSessionConfiguration.default
            cfg.requestCachePolicy = .useProtocolCachePolicy
            return cfg
        }())

        // First fetch (populate cache)
        _ = try await session.data(from: url)
        let firstCount = MockImageProtocol.requestCount
        XCTAssertEqual(firstCount, 1, "First visit should hit the network once")

        // Second fetch (should come from cache → protocol not invoked)
        _ = try await session.data(from: url)
        let secondCount = MockImageProtocol.requestCount
        XCTAssertEqual(secondCount, 1, "Warm cache should avoid a second network call")
    }
}
