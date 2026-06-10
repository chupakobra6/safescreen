import Foundation
import Testing
@testable import SafeScreenStage0Core

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
            from: ["SafeScreenStage0", "--ignored", "example.com"]
        )

        #expect(destination == .url(URL(string: "https://example.com")!))
    }

    @Test
    func destinationFallsBackToStartPageWithoutURL() {
        #expect(URLArgumentParser.destination(from: ["SafeScreenStage0"]) == .fallbackStartPage)
    }

    @Test
    func fallbackStartPageContainsLaunchCommand() {
        #expect(StartPage.html.contains("SafeScreen Stage 0"))
        #expect(StartPage.html.contains("swift run SafeScreenStage0"))
    }
}
