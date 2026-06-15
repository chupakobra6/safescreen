import Testing
import WebKit
@testable import SafeScreenStage0Browser

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
}
