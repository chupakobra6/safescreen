import AppKit
import OverlayBrowserCore
import OverlayBrowserWebKit
import WebKit

final class BrowserViewController: NSViewController, NSTextFieldDelegate, WKNavigationDelegate, WKUIDelegate {
    var onInputModeChanged: ((Bool) -> Void)?
    var onSessionNeedsSignIn: ((BrowserServiceTab) -> Void)?

    private let initialDestination: StartDestination
    private var observations: [NSKeyValueObservation] = []
    private var activeTab = BrowserServiceTab.chatGPT
    private var sessionStates: [BrowserServiceTab: BrowserSessionState] = [
        .chatGPT: .unknown,
        .aiStudio: .unknown
    ]
    private var notifiedSessionTabs: Set<BrowserServiceTab> = []
    private var isUpdatingAddress = false
    private var isInputMode = false

    private lazy var sessionMonitor = BrowserSessionMonitor { [weak self] tab, state in
        self?.setSessionState(state, for: tab)
    }

    private lazy var tabSelector: NSSegmentedControl = {
        let control = NSSegmentedControl(
            labels: BrowserServiceTab.allCases.map(\.title),
            trackingMode: .selectOne,
            target: self,
            action: #selector(selectTab)
        )
        control.selectedSegment = BrowserServiceTab.chatGPT.rawValue
        control.segmentStyle = .rounded
        control.setAccessibilityLabel("Вкладки браузера")
        return control
    }()

    private lazy var backButton = NSButton(
        title: "Back",
        target: self,
        action: #selector(goBack)
    )

    private lazy var forwardButton = NSButton(
        title: "Forward",
        target: self,
        action: #selector(goForward)
    )

    private lazy var reloadButton = NSButton(
        title: "Reload",
        target: self,
        action: #selector(reloadPage)
    )

    private lazy var addressField: AddressTextField = {
        let field = AddressTextField()
        field.placeholderString = "https://example.com"
        field.font = .systemFont(ofSize: 14)
        field.lineBreakMode = .byTruncatingMiddle
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.delegate = self
        field.target = self
        field.action = #selector(loadAddressFromField)
        field.onInteraction = { [weak self] in
            self?.enterInputMode()
        }
        return field
    }()

    private lazy var chatGPTWebView = makeWebView()
    private lazy var aiStudioWebView = makeWebView()

    private var allWebViews: [FocusAwareWebView] {
        [chatGPTWebView, aiStudioWebView]
    }

    private var activeWebView: FocusAwareWebView {
        webView(for: activeTab)
    }

    private func makeWebView() -> FocusAwareWebView {
        let configuration = BrowserProfile.makeWebViewConfiguration()
        let view = FocusAwareWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.underPageBackgroundColor = .textBackgroundColor
        view.onInputIntent = { [weak self] in
            self?.enterInputMode()
        }
        return view
    }

    init(initialDestination: StartDestination) {
        self.initialDestination = initialDestination
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupWebViewObservers()
        loadInitialDestinations()
        activateTab(.chatGPT)
        updateNavigationState()
    }

    func exitInputMode() {
        guard isInputMode else {
            AppLog.info(.input, "exit-ignored")
            return
        }

        isInputMode = false
        onInputModeChanged?(false)
    }

    func pasteFromClipboard() -> Bool {
        enterInputMode()

        guard let window = view.window else {
            AppLog.warning(.input, "paste-failed", ["reason": "missing-window"])
            return false
        }

        let pasteSelector = #selector(NSText.paste(_:))
        if NSApp.target(forAction: pasteSelector, to: nil, from: self) == nil {
            window.makeFirstResponder(activeWebView)
        }

        let pasted = NSApp.sendAction(pasteSelector, to: nil, from: self)
        AppLog.info(.input, "paste", ["handled": pasted ? "true" : "false"])
        return pasted
    }

    func controlTextDidBeginEditing(_ notification: Notification) {
        enterInputMode()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if let field = notification.object as? NSTextField {
            loadAddress(from: field.stringValue)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateVisibleNavigationState(for: webView)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            AppLog.info(.navigation, "start", navigationFields(for: webView, url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            AppLog.info(.navigation, "finish", navigationFields(for: webView, url: url))
        }
        if let tab = tab(for: webView) {
            sessionMonitor.refresh(tab: tab, webView: webView)
        }
        updateVisibleNavigationState(for: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        writeNavigationError(error, webView: webView)
        updateVisibleNavigationState(for: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        writeNavigationError(error, webView: webView)
        loadErrorPage(for: error, in: webView)
        updateVisibleNavigationState(for: webView)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else {
            return nil
        }

        AppLog.info(
            .navigation,
            "new-window-in-current-tab",
            navigationFields(for: webView, url: navigationAction.request.url)
        )
        webView.load(navigationAction.request)
        return nil
    }

    private func setupLayout() {
        let tabBar = NSStackView(views: [tabSelector])
        tabBar.orientation = .horizontal
        tabBar.alignment = .centerY
        tabBar.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 4, right: 8)

        let toolbar = NSStackView(views: [
            backButton,
            forwardButton,
            reloadButton,
            addressField
        ])
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 8, right: 8)

        let webViewContainer = NSView()
        allWebViews.forEach { webView in
            webView.translatesAutoresizingMaskIntoConstraints = false
            webViewContainer.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
                webView.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
                webView.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor)
            ])
        }
        aiStudioWebView.isHidden = true

        let rootStack = NSStackView(views: [tabBar, toolbar, webViewContainer])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.distribution = .fill
        rootStack.spacing = 0
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabBar.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            toolbar.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            webViewContainer.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])
    }

    private func setupWebViewObservers() {
        observations = allWebViews.flatMap { webView in
            [
                webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                    guard let self, let webView else {
                        return
                    }
                    self.updateVisibleNavigationState(for: webView)
                },
                webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                    guard let self, let webView else {
                        return
                    }
                    self.updateVisibleNavigationState(for: webView)
                },
                webView.observe(\.url, options: [.new]) { [weak self, weak webView] _, _ in
                    guard let self, let webView else {
                        return
                    }
                    self.updateVisibleNavigationState(for: webView)
                }
            ]
        }
    }

    private func loadInitialDestinations() {
        switch initialDestination {
        case .url(let url):
            AppLog.info(.navigation, "initial-url", ["url": url.absoluteString])
            load(url: url, in: chatGPTWebView, tab: .chatGPT)
        case .fallbackStartPage:
            AppLog.warning(.navigation, "initial-fallback")
            chatGPTWebView.loadHTMLString(StartPage.html, baseURL: nil)
        }
        load(url: BrowserServiceTab.aiStudio.defaultURL, in: aiStudioWebView, tab: .aiStudio)
    }

    private func enterInputMode() {
        guard !isInputMode else {
            return
        }

        isInputMode = true
        onInputModeChanged?(true)
    }

    @objc private func goBack() {
        if activeWebView.canGoBack {
            activeWebView.goBack()
        }
    }

    @objc private func goForward() {
        if activeWebView.canGoForward {
            activeWebView.goForward()
        }
    }

    @objc private func reloadPage() {
        activeWebView.reload()
    }

    @objc private func selectTab() {
        guard let tab = BrowserServiceTab(rawValue: tabSelector.selectedSegment) else {
            return
        }
        activateTab(tab)
    }

    @objc private func loadAddressFromField() {
        enterInputMode()
        loadAddress(from: addressField.stringValue)
    }

    private func loadAddress(from rawValue: String) {
        guard let url = URLArgumentParser.normalizedURL(from: rawValue) else {
            AppLog.warning(.navigation, "invalid-address", ["value": rawValue])
            updateAddressFromWebView()
            return
        }

        load(url: url, in: activeWebView, tab: activeTab)
    }

    private func load(url: URL, in webView: WKWebView, tab: BrowserServiceTab) {
        AppLog.info(.navigation, "load", ["tab": tab.title, "url": url.absoluteString])
        webView.load(URLRequest(url: url))
        if tab == activeTab {
            addressField.stringValue = url.absoluteString
        }
    }

    private func loadErrorPage(for error: Error, in webView: WKWebView) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        let message = escapeHTML(error.localizedDescription)
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body {
              margin: 0;
              padding: 32px;
              font: 14px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              color: #17202a;
              background: #ffffff;
            }
            h1 {
              margin: 0 0 12px;
              font-size: 18px;
            }
            p {
              margin: 0;
              line-height: 1.5;
            }
          </style>
        </head>
        <body>
          <h1>Page failed to load</h1>
          <p>\(message)</p>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }

    private func writeNavigationError(_ error: Error, webView: WKWebView) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        var fields = navigationFields(for: webView, url: webView.url)
        fields.merge([
            "description": error.localizedDescription,
            "domain": nsError.domain,
            "code": "\(nsError.code)"
        ]) { _, new in new }
        AppLog.error(.navigation, "fail", fields)
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func updateNavigationState() {
        backButton.isEnabled = activeWebView.canGoBack
        forwardButton.isEnabled = activeWebView.canGoForward
        reloadButton.isEnabled = true
    }

    private func updateAddressFromWebView() {
        guard !isUpdatingAddress else {
            return
        }

        guard let url = activeWebView.url else {
            return
        }

        isUpdatingAddress = true
        addressField.stringValue = url.absoluteString
        isUpdatingAddress = false
    }

    private func activateTab(_ tab: BrowserServiceTab) {
        if activeTab != tab {
            exitInputMode()
        }
        activeTab = tab
        tabSelector.selectedSegment = tab.rawValue
        chatGPTWebView.isHidden = tab != .chatGPT
        aiStudioWebView.isHidden = tab != .aiStudio
        updateAddressFromWebView()
        updateNavigationState()
        AppLog.info(.navigation, "tab-selected", ["tab": tab.title])
    }

    private func webView(for tab: BrowserServiceTab) -> FocusAwareWebView {
        switch tab {
        case .chatGPT:
            chatGPTWebView
        case .aiStudio:
            aiStudioWebView
        }
    }

    private func tab(for webView: WKWebView) -> BrowserServiceTab? {
        if webView === chatGPTWebView {
            return .chatGPT
        }
        if webView === aiStudioWebView {
            return .aiStudio
        }
        return nil
    }

    private func updateVisibleNavigationState(for webView: WKWebView) {
        guard webView === activeWebView else {
            return
        }
        updateAddressFromWebView()
        updateNavigationState()
    }

    private func navigationFields(for webView: WKWebView, url: URL?) -> [String: String] {
        var fields: [String: String] = [:]
        if let tab = tab(for: webView) {
            fields["tab"] = tab.title
        }
        if let url {
            fields["url"] = url.absoluteString
        }
        return fields
    }

    private func setSessionState(_ state: BrowserSessionState, for tab: BrowserServiceTab) {
        guard sessionStates[tab] != state else {
            return
        }
        sessionStates[tab] = state
        AppLog.info(.session, "state-changed", [
            "state": sessionStateName(state),
            "tab": tab.title
        ])
        if state == .authenticated {
            notifiedSessionTabs.remove(tab)
        } else if state == .needsSignIn, notifiedSessionTabs.insert(tab).inserted {
            onSessionNeedsSignIn?(tab)
        }
    }

    private func sessionStateName(_ state: BrowserSessionState) -> String {
        switch state {
        case .unknown:
            "unknown"
        case .authenticated:
            "authenticated"
        case .needsSignIn:
            "needs-sign-in"
        }
    }
}
