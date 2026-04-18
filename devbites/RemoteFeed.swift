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
    /// GitHub repository name (your repo is `kernel`).
    static let githubRepo = "kernel"
    static let branch = "main"

    /// App target folder in-repo: `devbites/ingested_feed.json` on the `main` branch.
    static var jsonURL: URL? {
        guard !githubOwner.isEmpty else {
            return nil
        }
        let s = "https://raw.githubusercontent.com/\(githubOwner)/\(githubRepo)/\(branch)/devbites/ingested_feed.json"
        return URL(string: s)
    }
}
