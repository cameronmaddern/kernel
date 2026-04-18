//
//  ContentView.swift
//  devbites
//

import SwiftUI

struct ContentView: View {
    @State private var articles: [Article] = []
    @State private var isLoadingFeed = true
    @State private var loadError: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    FeedTopStrip()
                        .padding(.bottom, 4)

                    if isLoadingFeed {
                        ProgressView()
                            .tint(AppTheme.brandOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 56)
                    } else if let err = loadError {
                        VStack(spacing: 20) {
                            ContentUnavailableView(
                                "Can’t load feed",
                                systemImage: "wifi.exclamationmark",
                                description: Text(err)
                            )
                            Button("Retry") {
                                Task { await loadFeed(showBlockingLoader: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.brandOrange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                    } else if articles.isEmpty {
                        ContentUnavailableView(
                            "Nothing to read yet",
                            systemImage: "tray",
                            description: Text("Run the “Ingest feed” workflow on GitHub, or wait for the daily schedule, then pull down to refresh.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    } else {
                        ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                            Button {
                                path.append(article)
                            } label: {
                                FeedPost(article: article)
                            }
                            .buttonStyle(FeedRowButtonStyle())
                            .accessibilityLabel("\(article.title), \(article.sourceName)")
                            .accessibilityHint("Opens the article")

                            if index < articles.count - 1 {
                                FeedSeparator(inset: FeedLayout.horizontalPadding)
                            }
                        }
                    }
                }
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await loadFeed(showBlockingLoader: false)
            }
            .background(AppTheme.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.navChrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NewsWordmark()
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")

                    Button {
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Alerts")
                }
            }
            .task {
                await loadFeed(showBlockingLoader: true)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleReaderView(article: article)
            }
        }
    }

    private func loadFeed(showBlockingLoader: Bool) async {
        if showBlockingLoader {
            isLoadingFeed = true
        }
        loadError = nil
        defer {
            if showBlockingLoader {
                isLoadingFeed = false
            }
        }
        do {
            articles = try await FeedLoader.loadFeed()
        } catch let e as FeedLoaderError {
            loadError = e.localizedDescription
            articles = []
        } catch {
            loadError = error.localizedDescription
            articles = []
        }
    }
}

// MARK: - Header

private struct NewsWordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Ker")
                .foregroundStyle(AppTheme.ink)
            Text("nel")
                .foregroundStyle(AppTheme.brandOrange)
        }
        .font(.system(size: 21, weight: .bold, design: .default))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kernel")
    }
}

// MARK: - Feed intro strip

private struct FeedTopStrip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.caption)
                .foregroundStyle(AppTheme.inkTertiary)

            sectionLabel("TOP STORIES")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FeedLayout.horizontalPadding)
        .padding(.top, 12)
    }
}

private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .semibold))
        .tracking(1.1)
        .foregroundStyle(AppTheme.inkTertiary)
}

// MARK: - Interaction

private struct FeedRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.94 : 1)
            .scaleEffect((configuration.isPressed && !reduceMotion) ? 0.99 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Feed post

private enum FeedLayout {
    static let horizontalPadding: CGFloat = 16
    static let imageHeight: CGFloat = 220
}

private struct FeedPost: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FeedHeroImage(article: article)
                .padding(.bottom, 14)

            Text(article.title)
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .padding(.bottom, 8)

            metadataLine
                .padding(.bottom, 10)

            if let summary = article.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkMuted)
                    .lineLimit(4)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FeedLayout.horizontalPadding)
        .padding(.vertical, 20)
    }

    private var metadataLine: some View {
        Text("\(article.sourceName) · \(article.publishedAt, format: .dateTime.month(.abbreviated).day().year())")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.inkTertiary)
            .accessibilityLabel("\(article.sourceName), \(article.publishedAt.formatted(date: .abbreviated, time: .omitted))")
    }
}

// MARK: - Separator

private struct FeedSeparator: View {
    let inset: CGFloat

    var body: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(height: 1)
            .padding(.leading, inset)
            .padding(.trailing, inset)
    }
}

// MARK: - Hero image

private struct FeedHeroImage: View {
    let article: Article

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            ZStack {
                AppTheme.hairline.opacity(0.35)

                if let url = article.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(AppTheme.brandOrange)
                                .frame(width: w, height: h)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: w, height: h)
                                .clipped()
                        case .failure:
                            heroPlaceholder(width: w, height: h)
                        @unknown default:
                            heroPlaceholder(width: w, height: h)
                        }
                    }
                } else {
                    heroPlaceholder(width: w, height: h)
                }
            }
            .frame(width: w, height: h, alignment: .center)
            .clipped()
        }
        .frame(height: FeedLayout.imageHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(AppTheme.hairline.opacity(0.9), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private func heroPlaceholder(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.hairline.opacity(0.5),
                    AppTheme.inkMuted.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "doc.richtext")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(AppTheme.inkTertiary)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

#Preview {
    ContentView()
}
