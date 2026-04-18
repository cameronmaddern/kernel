//
//  Article.swift
//  devbites
//

import Foundation

struct Article: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let sourceName: String
    let url: URL
    let publishedAt: Date
    let summary: String?
    /// Hero/thumbnail when known (often from RSS HTML, `media:thumbnail`, or Open Graph during ingest).
    let imageURL: URL?
}

struct ArticleFeed: Codable {
    let articles: [Article]
}

enum FeedLoaderError: LocalizedError {
    case notConfigured
    case badResponse
    case httpStatus(Int)
    case decode

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Set RemoteFeed.githubOwner to your GitHub username (same repo that runs the ingest workflow)."
        case .badResponse:
            return "Unexpected response from the feed server."
        case .httpStatus(let code):
            return "Feed request failed (HTTP \(code))."
        case .decode:
            return "Couldn’t read the feed data."
        }
    }
}

enum FeedLoader {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Loads only from `RemoteFeed.jsonURL` (raw `ingested_feed.json` on GitHub). No bundled fallback.
    static func loadFeed() async throws -> [Article] {
        guard let url = RemoteFeed.jsonURL else {
            throw FeedLoaderError.notConfigured
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Kernel/1.0", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            throw FeedLoaderError.badResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw FeedLoaderError.httpStatus(http.statusCode)
        }
        let feed: ArticleFeed
        do {
            feed = try decoder.decode(ArticleFeed.self, from: data)
        } catch {
            throw FeedLoaderError.decode
        }
        return feed.articles.sorted { $0.publishedAt > $1.publishedAt }
    }

#if DEBUG
    /// For SwiftUI previews only — uses bundled `sample_feed.json`.
    static func previewArticles() -> [Article] {
        guard let url = Bundle.main.url(forResource: "sample_feed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let feed = try? decoder.decode(ArticleFeed.self, from: data)
        else {
            return []
        }
        return feed.articles.sorted { $0.publishedAt > $1.publishedAt }
    }
#endif
}
