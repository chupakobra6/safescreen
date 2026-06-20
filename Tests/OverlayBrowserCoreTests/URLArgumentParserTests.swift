import Foundation
import Testing
@testable import OverlayBrowserCore

@Suite("URLArgumentParser")
struct URLArgumentParserTests {
    @Test
    func addsHTTPSWhenSchemeIsMissing() throws {
        let url = try #require(URLArgumentParser.normalizedURL(from: "example.com"))

        #expect(url.absoluteString == "https://example.com")
    }

    @Test
    func keepsHTTPSSchemeAndPath() throws {
        let url = try #require(URLArgumentParser.normalizedURL(from: "https://example.com/docs?q=stage0"))

        #expect(url.absoluteString == "https://example.com/docs?q=stage0")
    }

    @Test
    func keepsHTTPForLocalTesting() throws {
        let url = try #require(URLArgumentParser.normalizedURL(from: "http://localhost:8080/focus.html"))

        #expect(url.absoluteString == "http://localhost:8080/focus.html")
    }

    @Test
    func rejectsUnsupportedScheme() {
        #expect(URLArgumentParser.normalizedURL(from: "file:///tmp/test.html") == nil)
    }

    @Test
    func destinationUsesFirstMeaningfulURLArgument() {
        let destination = URLArgumentParser.destination(
            from: ["OverlayBrowser", "--ignored", "example.com"]
        )

        #expect(destination == .url(URL(string: "https://example.com")!))
    }

    @Test
    func destinationDefaultsToChatGPTWithoutURL() {
        #expect(URLArgumentParser.destination(from: ["OverlayBrowser"]) == .url(URLArgumentParser.defaultURL))
    }

    @Test
    func destinationFallsBackToStartPageForInvalidURL() {
        #expect(
            URLArgumentParser.destination(from: ["OverlayBrowser", "file:///tmp/test.html"]) == .fallbackStartPage
        )
    }

    @Test
    func fallbackStartPageContainsLaunchCommand() {
        #expect(StartPage.html.contains("Overlay Browser"))
        #expect(StartPage.html.contains("swift run OverlayBrowser"))
    }
}
