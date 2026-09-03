import OverlayBrowserCore
import WebKit

@MainActor
final class BrowserSessionMonitor {
    typealias StateHandler = (BrowserServiceTab, BrowserSessionState) -> Void

    private static let chatGPTCheckScript = """
    const loginControl = document.querySelector([
        'input[type="email"]',
        'input[autocomplete="username"]',
        '[data-testid="login-button"]',
        'a[href*="/auth/login"]',
        'a[href*="/log-in"]'
    ].join(','));
    if (loginControl) {
        return false;
    }

    try {
        const response = await fetch('/api/auth/session', {
            credentials: 'include',
            cache: 'no-store'
        });
        if (response.ok) {
            const session = await response.json();
            if (session && session.user) {
                return true;
            }
            if (session && typeof session === 'object') {
                return false;
            }
        }
    } catch (_) {
        return null;
    }
    return null;
    """

    private let onStateChanged: StateHandler

    init(onStateChanged: @escaping StateHandler) {
        self.onStateChanged = onStateChanged
    }

    func refresh(tab: BrowserServiceTab, webView: WKWebView) {
        refreshNow(tab: tab, webView: webView)

        let navigationURL = webView.url
        Task { @MainActor [weak self, weak webView] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self, let webView, webView.url == navigationURL else {
                return
            }
            self.refreshNow(tab: tab, webView: webView)
        }
    }

    private func refreshNow(tab: BrowserServiceTab, webView: WKWebView) {
        let immediateState = BrowserSessionPolicy.state(for: tab, currentURL: webView.url)
        if immediateState == .needsSignIn {
            onStateChanged(tab, .needsSignIn)
            return
        }

        switch tab {
        case .chatGPT:
            guard BrowserSessionPolicy.state(
                for: tab,
                currentURL: webView.url,
                hasAuthenticatedSession: true
            ) == .authenticated else {
                onStateChanged(tab, .unknown)
                return
            }
            checkChatGPTSession(tab: tab, webView: webView)
        case .aiStudio:
            let state = BrowserSessionPolicy.state(
                for: tab,
                currentURL: webView.url,
                hasAuthenticatedSession: true
            )
            onStateChanged(tab, state)
        }
    }

    private func checkChatGPTSession(tab: BrowserServiceTab, webView: WKWebView) {
        let navigationURL = webView.url
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else {
                return
            }
            do {
                let value = try await webView.callAsyncJavaScript(
                    Self.chatGPTCheckScript,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                guard webView.url == navigationURL else {
                    return
                }
                guard let authenticated = value as? Bool else {
                    self.onStateChanged(tab, .unknown)
                    return
                }
                let state = BrowserSessionPolicy.state(
                    for: tab,
                    currentURL: webView.url,
                    hasAuthenticatedSession: authenticated
                )
                self.onStateChanged(tab, state)
            } catch {
                AppLog.warning(.session, "check-failed", [
                    "description": error.localizedDescription,
                    "tab": tab.title
                ])
                self.onStateChanged(tab, .unknown)
            }
        }
    }
}
