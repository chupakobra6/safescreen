import Foundation
import WebKit

@MainActor
public enum BrowserProfile {
    public static let websiteDataStoreIdentifier = UUID(
        uuidString: "4B801A03-C12C-4C5C-89CE-28D85E385B77"
    )!

    private static let websiteDataStore = WKWebsiteDataStore(
        forIdentifier: websiteDataStoreIdentifier
    )

    public static func makeWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore
        return configuration
    }
}
