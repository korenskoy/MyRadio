import Foundation

/// Records the app's OWN outbound HTTP requests (iTunes lookups, favicon/artwork
/// downloads, update checks) for the DevTools Network tab.
///
/// Note: RadioBrowserKit performs its API calls through its own internal
/// `HTTPClient`, which exposes no request hook, so those calls are NOT captured
/// here — only requests we issue directly through `tracked(...)`.
@MainActor
@Observable
final class NetworkActivityLog {
    static let shared = NetworkActivityLog()

    struct Record: Identifiable {
        let id = UUID()
        let time: String
        let method: String
        let url: String
        let status: Int   // 0 == transport failure (no HTTP response)
        let ms: Int
        let bytes: Int
    }

    private(set) var records: [Record] = []
    private let capacity = 200

    private init() {}

    func clear() {
        records.removeAll()
    }

    /// Records one finished request. Safe to call from any thread/actor.
    nonisolated func add(method: String, url: String, status: Int, ms: Int, bytes: Int) {
        let record = Record(time: Self.timestamp(), method: method, url: url, status: status, ms: ms, bytes: bytes)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.records.append(record)
            if self.records.count > self.capacity {
                self.records.removeFirst(self.records.count - self.capacity)
            }
        }
    }

    /// Performs a GET and records its timing/status/size. Mirrors
    /// `URLSession.data(from:)` so call sites barely change.
    nonisolated func tracked(_ url: URL, session: URLSession = .shared) async throws -> (Data, URLResponse) {
        let start = Date()
        do {
            let (data, response) = try await session.data(from: url)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            add(method: "GET", url: url.absoluteString, status: status, ms: ms, bytes: data.count)
            return (data, response)
        } catch {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            add(method: "GET", url: url.absoluteString, status: 0, ms: ms, bytes: 0)
            throw error
        }
    }

    /// `URLRequest` variant for callers that set headers/method explicitly.
    nonisolated func tracked(_ request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        let start = Date()
        let method = request.httpMethod ?? "GET"
        let urlString = request.url?.absoluteString ?? "—"
        do {
            let (data, response) = try await session.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            add(method: method, url: urlString, status: status, ms: ms, bytes: data.count)
            return (data, response)
        } catch {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            add(method: method, url: urlString, status: 0, ms: ms, bytes: 0)
            throw error
        }
    }

    nonisolated private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    nonisolated private static func timestamp() -> String {
        formatter.string(from: Date())
    }
}
