import Foundation

public enum URLArgumentParser {
    public static let defaultURL = URL(string: "https://chatgpt.com/")!

    public static func destination(from arguments: [String]) -> StartDestination {
        guard let rawURL = arguments
            .dropFirst()
            .first(where: { argument in
                let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && trimmed != "--" && !trimmed.hasPrefix("-")
            })
        else {
            return .url(defaultURL)
        }

        guard let url = normalizedURL(from: rawURL) else {
            return .fallbackStartPage
        }

        return .url(url)
    }

    public static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let candidate: String
        if trimmed.contains("://") {
            candidate = trimmed
        } else {
            candidate = "https://\(trimmed)"
        }

        guard
            let components = URLComponents(string: candidate),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            let url = components.url
        else {
            return nil
        }

        return url
    }
}
