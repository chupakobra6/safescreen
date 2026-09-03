import Foundation

public enum BrowserProfileMigrationResult: Equatable {
    case notCanonicalBundle
    case noLegacyProfile
    case alreadyCompleted
    case migrated(backupURL: URL?)
}

public enum BrowserProfileMigration {
    public static let migrationID = "legacy-overlaybrowser-profile-v1"

    public static func migrateIfNeeded(
        legacyRoot: URL,
        canonicalRoot: URL,
        stateDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> BrowserProfileMigrationResult {
        let markerURL = stateDirectory.appendingPathComponent("\(migrationID).completed")
        if fileManager.fileExists(atPath: markerURL.path) {
            return .alreadyCompleted
        }

        guard fileManager.fileExists(atPath: legacyRoot.path) else {
            return .noLegacyProfile
        }

        let legacyPath = legacyRoot.standardizedFileURL.path
        let canonicalPath = canonicalRoot.standardizedFileURL.path
        precondition(legacyPath != canonicalPath, "Legacy and canonical profile paths must differ")

        try fileManager.createDirectory(
            at: canonicalRoot.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)

        let stagingURL = canonicalRoot.deletingLastPathComponent().appendingPathComponent(
            ".\(canonicalRoot.lastPathComponent)-migration-\(UUID().uuidString)",
            isDirectory: true
        )
        defer {
            try? fileManager.removeItem(at: stagingURL)
        }

        try fileManager.copyItem(at: legacyRoot, to: stagingURL)

        var backupURL: URL?
        if fileManager.fileExists(atPath: canonicalRoot.path) {
            let backupDirectory = stateDirectory.appendingPathComponent("ProfileBackups", isDirectory: true)
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let candidate = backupDirectory.appendingPathComponent(
                "\(canonicalRoot.lastPathComponent)-\(UUID().uuidString).backup",
                isDirectory: true
            )
            try fileManager.copyItem(at: canonicalRoot, to: candidate)
            backupURL = candidate
            try fileManager.removeItem(at: canonicalRoot)
        }

        try fileManager.moveItem(at: stagingURL, to: canonicalRoot)

        let marker = "source=\(legacyPath)\ndestination=\(canonicalPath)\n"
        try marker.write(to: markerURL, atomically: true, encoding: .utf8)
        return .migrated(backupURL: backupURL)
    }
}
