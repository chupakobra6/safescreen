import Foundation

enum AppLog {
    enum Category: String {
        case app
        case hotKey = "hotkey"
        case input
        case navigation
        case profile
        case session
        case window
    }

    static func info(_ category: Category, _ event: String, _ fields: [String: String] = [:]) {
        write(level: "info", category: category, event: event, fields: fields)
    }

    static func warning(_ category: Category, _ event: String, _ fields: [String: String] = [:]) {
        write(level: "warning", category: category, event: event, fields: fields)
    }

    static func error(_ category: Category, _ event: String, _ fields: [String: String] = [:]) {
        write(level: "error", category: category, event: event, fields: fields)
    }

    private static func write(level: String, category: Category, event: String, fields: [String: String]) {
        var parts = [
            "app=OverlayBrowser",
            "level=\(level)",
            "pid=\(ProcessInfo.processInfo.processIdentifier)",
            "category=\(category.rawValue)",
            "event=\(event)"
        ]

        for key in fields.keys.sorted() {
            if let value = fields[key] {
                parts.append("\(key)=\(quote(value))")
            }
        }

        fputs("[OverlayBrowser] \(parts.joined(separator: " "))\n", stderr)
    }

    private static func quote(_ value: String) -> String {
        if value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
           value.rangeOfCharacter(from: CharacterSet(charactersIn: "\"")) == nil {
            return value
        }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
