//
//  ArticleReaderView.swift
//  devbites
//

import SwiftUI
import WebKit

struct ArticleReaderView: View {
    let article: Article

    @State private var isLoading = true
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.canvas
                .ignoresSafeArea()

            InAppWebView(url: article.url, isLoading: $isLoading)
                .opacity(isLoading ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: isLoading)

            if isLoading {
                ProgressView()
                    .tint(AppTheme.brandOrange)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.canvas)
            }
        }
        .navigationTitle(titleDisplay)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.navChrome, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: article.url) {
                        Label("Share link", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        openURL(article.url)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Article actions")
            }
        }
    }

    private var titleDisplay: String {
        let t = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 42 {
            return t
        }
        return String(t.prefix(39)) + "…"
    }
}

// MARK: - WKWebView

private struct InAppWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = AppTheme.canvasUIColor
        webView.scrollView.backgroundColor = AppTheme.canvasUIColor
        webView.allowsBackForwardNavigationGestures = false
        let request = URLRequest(url: url)
        isLoading = true
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: InAppWebView

        init(_ parent: InAppWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        ArticleReaderView(
            article: Article(
                id: "p",
                title: "Sample article title for preview",
                sourceName: "Example",
                url: URL(string: "https://example.com")!,
                publishedAt: Date(),
                summary: nil,
                imageURL: nil
            )
        )
    }
}
