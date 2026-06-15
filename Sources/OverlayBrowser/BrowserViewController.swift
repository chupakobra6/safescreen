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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateAddressFromWebView()
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
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

            addressField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),

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
            load(url: url)
        case .fallbackStartPage:
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
            NSSound.beep()
            updateAddressFromWebView()
            return
        }

        load(url: url)
    }

    private func load(url: URL) {
        webView.load(URLRequest(url: url))
        addressField.stringValue = url.absoluteString
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

    override func mouseDown(with event: NSEvent) {
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

    override func mouseDown(with event: NSEvent) {
        onInputIntent?()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onInputIntent?()
        super.rightMouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        onInputIntent?()
        super.keyDown(with: event)
    }
}
