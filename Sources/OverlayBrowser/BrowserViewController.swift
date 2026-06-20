import AppKit
import OverlayBrowserCore
import OverlayBrowserWebKit
import WebKit

final class BrowserViewController: NSViewController, NSTextFieldDelegate, WKNavigationDelegate {
    var onInputModeChanged: ((Bool) -> Void)?

    private let initialDestination: StartDestination
    private var observations: [NSKeyValueObservation] = []
    private var isUpdatingAddress = false
    private var isInputMode = false

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

    private lazy var webView: FocusAwareWebView = {
        let configuration = BrowserProfile.makeWebViewConfiguration()
        let view = FocusAwareWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.underPageBackgroundColor = .textBackgroundColor
        view.onInputIntent = { [weak self] in
            self?.enterInputMode()
        }
        return view
    }()

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
        loadInitialDestination()
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

    func controlTextDidBeginEditing(_ notification: Notification) {
        enterInputMode()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if let field = notification.object as? NSTextField {
            loadAddress(from: field.stringValue)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateAddressFromWebView()
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            AppLog.info(.navigation, "start", ["url": url.absoluteString])
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            AppLog.info(.navigation, "finish", ["url": url.absoluteString])
        }
        updateAddressFromWebView()
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        writeNavigationError(error)
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        writeNavigationError(error)
        loadErrorPage(for: error)
        updateNavigationState()
    }

    private func setupLayout() {
        let toolbar = NSStackView(views: [
            backButton,
            forwardButton,
            reloadButton,
            addressField
        ])
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        [toolbar, webView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),

            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupWebViewObservers() {
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, _ in
                self?.updateNavigationState()
            },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                self?.updateAddressFromWebView()
            }
        ]
    }

    private func loadInitialDestination() {
        switch initialDestination {
        case .url(let url):
            AppLog.info(.navigation, "initial-url", ["url": url.absoluteString])
            load(url: url)
        case .fallbackStartPage:
            AppLog.warning(.navigation, "initial-fallback")
            webView.loadHTMLString(StartPage.html, baseURL: nil)
        }
    }

    private func enterInputMode() {
        guard !isInputMode else {
            return
        }

        isInputMode = true
        onInputModeChanged?(true)
    }

    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc private func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    @objc private func reloadPage() {
        webView.reload()
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

        load(url: url)
    }

    private func load(url: URL) {
        AppLog.info(.navigation, "load", ["url": url.absoluteString])
        webView.load(URLRequest(url: url))
        addressField.stringValue = url.absoluteString
    }

    private func loadErrorPage(for error: Error) {
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

    private func writeNavigationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        AppLog.error(.navigation, "fail", [
            "description": error.localizedDescription,
            "domain": nsError.domain,
            "code": "\(nsError.code)"
        ])
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
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
        reloadButton.isEnabled = true
    }

    private func updateAddressFromWebView() {
        guard !isUpdatingAddress else {
            return
        }

        guard let url = webView.url else {
            return
        }

        isUpdatingAddress = true
        addressField.stringValue = url.absoluteString
        isUpdatingAddress = false
    }
}

private final class AddressTextField: NSTextField {
    var onInteraction: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.arrow.set()
        onInteraction?()
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        onInteraction?()
        return super.becomeFirstResponder()
    }
}

private final class FocusAwareWebView: WKWebView {
    var onInputIntent: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.arrow.set()
        onInputIntent?()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSCursor.arrow.set()
        onInputIntent?()
        super.rightMouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        onInputIntent?()
        super.keyDown(with: event)
    }
}
