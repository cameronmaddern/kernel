//
//  RemoteFeed.swift
//  devbites
//
//  The app loads feed JSON only from GitHub raw (updated by `.github/workflows/ingest-feed.yml`).
//

import Foundation

enum RemoteFeed {
    /// GitHub user/org that hosts this repo (raw feed URL).
    static let githubOwner = "cameronmaddern"
    static let githubRepo = "devbites"
    static let branch = "main"

    /// `https://raw.githubusercontent.com/<owner>/<repo>/<branch>/devbites/ingested_feed.json`
    static var jsonURL: URL? {
        guard !githubOwner.isEmpty else {
            return nil
        }
        let s = "https://raw.githubusercontent.com/\(githubOwner)/\(githubRepo)/\(branch)/devbites/ingested_feed.json"
        return URL(string: s)
    }
}
