import Foundation
import Testing
@testable import OverlayBrowserWebKit

@Suite("Browser profile migration")
struct BrowserProfileMigrationTests {
    @Test
    func reportsMissingLegacyProfileWithoutCreatingState() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        let result = try fixture.migrate()

        #expect(result == .noLegacyProfile)
        #expect(!FileManager.default.fileExists(atPath: fixture.canonical.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.state.path))
    }

    @Test
    func migratesLegacyProfileAndBacksUpExistingCanonicalData() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.write("legacy-session", to: fixture.legacy)
        try fixture.write("new-empty-session", to: fixture.canonical)

        let result = try fixture.migrate()
        guard case .migrated(let backupURL) = result else {
            Issue.record("Expected migrated result")
            return
        }

        #expect(try fixture.read(from: fixture.canonical) == "legacy-session")
        let backup = try #require(backupURL)
        #expect(try fixture.read(from: backup) == "new-empty-session")
    }

    @Test
    func completedMigrationDoesNotOverwriteLaterCanonicalChanges() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.write("legacy-session", to: fixture.legacy)

        _ = try fixture.migrate()
        try fixture.write("current-session", to: fixture.canonical)
        let secondResult = try fixture.migrate()

        #expect(secondResult == .alreadyCompleted)
        #expect(try fixture.read(from: fixture.canonical) == "current-session")
    }
}

private struct Fixture {
    let root: URL
    let legacy: URL
    let canonical: URL
    let state: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "overlay-profile-migration-\(UUID().uuidString)",
            isDirectory: true
        )
        legacy = root.appendingPathComponent("legacy", isDirectory: true)
        canonical = root.appendingPathComponent("canonical", isDirectory: true)
        state = root.appendingPathComponent("state", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func migrate() throws -> BrowserProfileMigrationResult {
        try BrowserProfileMigration.migrateIfNeeded(
            legacyRoot: legacy,
            canonicalRoot: canonical,
            stateDirectory: state
        )
    }

    func write(_ value: String, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try value.write(
            to: directory.appendingPathComponent("session.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    func read(from directory: URL) throws -> String {
        try String(
            contentsOf: directory.appendingPathComponent("session.txt"),
            encoding: .utf8
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
