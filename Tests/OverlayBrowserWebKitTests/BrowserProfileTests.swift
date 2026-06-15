import Testing
import WebKit
@testable import OverlayBrowserWebKit

@MainActor
@Suite("BrowserProfile")
struct BrowserProfileTests {
    @Test
    func usesPersistentWebsiteDataStoreWithStableIdentifier() {
        let configuration = BrowserProfile.makeWebViewConfiguration()
        let dataStore = configuration.websiteDataStore

        #expect(dataStore.isPersistent)
        #expect(dataStore.identifier == BrowserProfile.websiteDataStoreIdentifier)
    }

    @Test
    func reusesWebsiteDataStoreAcrossConfigurations() {
        let firstConfiguration = BrowserProfile.makeWebViewConfiguration()
        let secondConfiguration = BrowserProfile.makeWebViewConfiguration()

        #expect(firstConfiguration.websiteDataStore === secondConfiguration.websiteDataStore)
    }

    @Test
    func injectsFixedCursorPolicyIntoAllFrames() throws {
        let configuration = BrowserProfile.makeWebViewConfiguration()
        let userScripts = configuration.userContentController.userScripts
        let fixedCursorScript = try #require(userScripts.first {
            $0.source == BrowserProfile.fixedCursorUserScriptSource
        })

        #expect(fixedCursorScript.injectionTime == .atDocumentStart)
        #expect(fixedCursorScript.isForMainFrameOnly == false)
        #expect(fixedCursorScript.source.contains("cursor: default !important"))
        #expect(fixedCursorScript.source.contains("MutationObserver"))
        #expect(fixedCursorScript.source.contains("style.setProperty(\"cursor\", cursorValue, \"important\")"))
    }

    @Test
    func requiresUserActionForMediaPlayback() {
        let configuration = BrowserProfile.makeWebViewConfiguration()

        #expect(configuration.mediaTypesRequiringUserActionForPlayback == .all)
    }

    @Test
    func injectsSilentMediaPolicyIntoAllFrames() throws {
        let configuration = BrowserProfile.makeWebViewConfiguration()
        let userScripts = configuration.userContentController.userScripts
        let silentMediaScript = try #require(userScripts.first {
            $0.source == BrowserProfile.silentMediaUserScriptSource
        })

        #expect(silentMediaScript.injectionTime == .atDocumentStart)
        #expect(silentMediaScript.isForMainFrameOnly == false)
        #expect(silentMediaScript.source.contains("HTMLMediaElement"))
        #expect(silentMediaScript.source.contains("AudioContext"))
        #expect(silentMediaScript.source.contains("node.volume = 0"))
        #expect(silentMediaScript.source.contains("node.muted = true"))
    }
}
