import Foundation

public enum BrowserServiceTab: Int, CaseIterable, Equatable {
    case chatGPT
    case aiStudio

    public var title: String {
        switch self {
        case .chatGPT:
            "ChatGPT"
        case .aiStudio:
            "AI Studio"
        }
    }

    public var defaultURL: URL {
        switch self {
        case .chatGPT:
            URLArgumentParser.defaultURL
        case .aiStudio:
            URL(string: "https://aistudio.google.com/")!
        }
    }
}

public enum BrowserSessionState: Equatable {
    case unknown
    case authenticated
    case needsSignIn
}

public enum BrowserSessionPolicy {
    public static func state(
        for tab: BrowserServiceTab,
        currentURL: URL?,
        hasAuthenticatedSession: Bool? = nil
    ) -> BrowserSessionState {
        guard let host = currentURL?.host?.lowercased() else {
            return .unknown
        }

        switch tab {
        case .chatGPT:
            if hostMatches(host, domain: "auth.openai.com") {
                return .needsSignIn
            }
            guard hostMatches(host, domain: "chatgpt.com") else {
                return .unknown
            }
        case .aiStudio:
            if hostMatches(host, domain: "accounts.google.com") {
                return .needsSignIn
            }
            guard hostMatches(host, domain: "aistudio.google.com") else {
                return .unknown
            }
            if currentURL?.path == "/welcome" {
                return .needsSignIn
            }
        }

        guard let hasAuthenticatedSession else {
            return .unknown
        }
        return hasAuthenticatedSession ? .authenticated : .needsSignIn
    }

    private static func hostMatches(_ host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }
}
