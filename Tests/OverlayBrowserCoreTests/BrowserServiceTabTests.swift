import Foundation
import Testing
@testable import OverlayBrowserCore

@Suite("Browser service tabs")
struct BrowserServiceTabTests {
    @Test
    func definesChatGPTAsTheFirstDefaultTab() {
        #expect(BrowserServiceTab.allCases == [.chatGPT, .aiStudio])
        #expect(BrowserServiceTab.chatGPT.defaultURL.absoluteString == "https://chatgpt.com/")
        #expect(BrowserServiceTab.aiStudio.defaultURL.absoluteString == "https://aistudio.google.com/")
    }

    @Test
    func detectsKnownSignInDestinations() throws {
        let openAIAuth = try #require(URL(string: "https://auth.openai.com/log-in"))
        let googleAuth = try #require(URL(string: "https://accounts.google.com/ServiceLogin"))
        let aiStudioWelcome = try #require(URL(string: "https://aistudio.google.com/welcome"))

        #expect(BrowserSessionPolicy.state(for: .chatGPT, currentURL: openAIAuth) == .needsSignIn)
        #expect(BrowserSessionPolicy.state(for: .aiStudio, currentURL: googleAuth) == .needsSignIn)
        #expect(BrowserSessionPolicy.state(for: .aiStudio, currentURL: aiStudioWelcome) == .needsSignIn)
    }

    @Test
    func usesSiteSessionResultOnlyOnKnownServiceHosts() throws {
        let chatGPT = try #require(URL(string: "https://chatgpt.com/"))
        let aiStudio = try #require(URL(string: "https://aistudio.google.com/"))
        let local = try #require(URL(string: "http://localhost:8080/"))

        #expect(
            BrowserSessionPolicy.state(
                for: .chatGPT,
                currentURL: chatGPT,
                hasAuthenticatedSession: false
            ) == .needsSignIn
        )
        #expect(
            BrowserSessionPolicy.state(
                for: .aiStudio,
                currentURL: aiStudio,
                hasAuthenticatedSession: true
            ) == .authenticated
        )
        #expect(
            BrowserSessionPolicy.state(
                for: .chatGPT,
                currentURL: local,
                hasAuthenticatedSession: false
            ) == .unknown
        )
    }
}
