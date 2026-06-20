import Foundation
import Testing

@Suite("OverlayFocusGuardExtension")
struct ExtensionManifestTests {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var extensionRoot: URL {
        repositoryRoot
            .appendingPathComponent("Extensions")
            .appendingPathComponent("OverlayFocusGuard")
    }

    @Test
    func manifestDeclaresMainAndIsolatedDocumentStartScripts() throws {
        let manifest = try readManifest()

        #expect(manifest["manifest_version"] as? Int == 3)
        #expect(manifest["name"] as? String == "Overlay Focus Guard")

        let permissions = try #require(manifest["permissions"] as? [String])
        #expect(permissions.contains("storage"))
        #expect(permissions.contains("tabs"))

        let background = try #require(manifest["background"] as? [String: Any])
        #expect(background["service_worker"] as? String == "background.js")

        let contentScripts = try #require(manifest["content_scripts"] as? [[String: Any]])
        let mainScript = try #require(contentScripts.first {
            ($0["world"] as? String) == "MAIN"
        })
        let isolatedScript = try #require(contentScripts.first {
            ($0["world"] as? String) == "ISOLATED"
        })

        try expectContentScript(mainScript, file: "page-guard.js")
        try expectContentScript(isolatedScript, file: "content.js")
    }

    @Test
    func pageGuardPatchesFocusAndVisibilityBehindToggle() throws {
        let source = try readExtensionFile("page-guard.js")

        #expect(source.contains("overlay-focus-guard:set-enabled"))
        #expect(source.contains("patchGetter(Document.prototype, \"hidden\", false)"))
        #expect(source.contains("patchGetter(Document.prototype, \"visibilityState\", \"visible\")"))
        #expect(source.contains("patchMethod(Document.prototype, \"hasFocus\", () => true)"))
        #expect(source.contains("\"blur\", \"visibilitychange\", \"webkitvisibilitychange\", \"pagehide\", \"freeze\""))
        #expect(source.contains("dispatchingRecoveryEvent"))
        #expect(source.contains("install();"))
        #expect(!source.contains("__overlayFocusGuard"))
    }

    @Test
    func popupUsesPerOriginStorageToggle() throws {
        let source = try readExtensionFile("popup.js")

        #expect(source.contains("const storageKey = \"enabledOrigins\""))
        #expect(source.contains("url.origin"))
        #expect(source.contains("Enable for this site"))
        #expect(source.contains("Disable for this site"))
        #expect(source.contains("chrome.storage.local.set"))
        #expect(source.contains("document.readyState === \"loading\""))
    }

    @Test
    func backgroundShowsBadgeForEnabledOrigin() throws {
        let source = try readExtensionFile("background.js")

        #expect(source.contains("const storageKey = \"enabledOrigins\""))
        #expect(source.contains("chrome.action.setBadgeText"))
        #expect(source.contains("text: enabled ? \"ON\" : \"\""))
        #expect(source.contains("chrome.tabs.onActivated"))
        #expect(source.contains("chrome.storage.onChanged"))
    }

    @Test
    func extensionScriptsUseSharedLogPrefix() throws {
        for file in ["page-guard.js", "content.js", "background.js", "popup.js"] {
            let source = try readExtensionFile(file)
            #expect(source.contains("[OverlayFocusGuard]"))
        }
    }

    private func expectContentScript(_ script: [String: Any], file: String) throws {
        let matches = try #require(script["matches"] as? [String])
        let js = try #require(script["js"] as? [String])

        #expect(matches == ["<all_urls>"])
        #expect(js == [file])
        #expect(script["run_at"] as? String == "document_start")
        #expect(script["all_frames"] as? Bool == true)
        #expect(script["match_about_blank"] as? Bool == true)
        #expect(script["match_origin_as_fallback"] as? Bool == true)
    }

    private func readManifest() throws -> [String: Any] {
        let manifestURL = extensionRoot.appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: manifestURL)
        let json = try JSONSerialization.jsonObject(with: data)
        return try #require(json as? [String: Any])
    }

    private func readExtensionFile(_ path: String) throws -> String {
        let fileURL = extensionRoot.appendingPathComponent(path)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
