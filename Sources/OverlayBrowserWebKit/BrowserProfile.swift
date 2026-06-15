import Foundation
import WebKit

@MainActor
public enum BrowserProfile {
    public static let websiteDataStoreIdentifier = UUID(
        uuidString: "4B801A03-C12C-4C5C-89CE-28D85E385B77"
    )!
    public static let fixedCursorUserScriptSource = """
    (() => {
        const styleID = "overlay-browser-fixed-cursor-style";
        const cursorValue = "default";
        let isWatchingCursor = false;
        const css = `
            *, *::before, *::after {
                cursor: default !important;
            }
        `;

        function installFixedCursorStyle() {
            if (document.getElementById(styleID)) {
                return;
            }

            const style = document.createElement("style");
            style.id = styleID;
            style.textContent = css;

            const parent = document.head || document.documentElement;
            if (parent) {
                parent.appendChild(style);
            }
        }

        function applyInlineCursor(node) {
            if (!(node instanceof Element)) {
                return;
            }

            if (
                node.style.getPropertyValue("cursor") === cursorValue &&
                node.style.getPropertyPriority("cursor") === "important"
            ) {
                return;
            }

            node.style.setProperty("cursor", cursorValue, "important");
        }

        function applySubtreeCursor(root) {
            if (!(root instanceof Element)) {
                return;
            }

            applyInlineCursor(root);
            root.querySelectorAll("*").forEach(applyInlineCursor);
        }

        function watchCursorChanges() {
            if (isWatchingCursor) {
                return;
            }

            if (!document.documentElement) {
                return;
            }

            const observer = new MutationObserver((mutations) => {
                for (const mutation of mutations) {
                    if (mutation.type === "attributes") {
                        applyInlineCursor(mutation.target);
                    }

                    for (const node of mutation.addedNodes) {
                        applySubtreeCursor(node);
                    }
                }
            });

            observer.observe(document.documentElement, {
                attributes: true,
                attributeFilter: ["class", "style"],
                childList: true,
                subtree: true
            });
            isWatchingCursor = true;
        }

        document.addEventListener("mouseover", (event) => {
            applyInlineCursor(event.target);
        }, true);

        document.addEventListener("mousemove", (event) => {
            applyInlineCursor(event.target);
        }, true);

        installFixedCursorStyle();
        applySubtreeCursor(document.documentElement);
        watchCursorChanges();

        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", () => {
                installFixedCursorStyle();
                applySubtreeCursor(document.documentElement);
                watchCursorChanges();
            }, { once: true });
        }
    })();
    """

    private static let websiteDataStore = WKWebsiteDataStore(
        forIdentifier: websiteDataStoreIdentifier
    )

    public static func makeWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        let fixedCursorUserScript = WKUserScript(
            source: fixedCursorUserScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        userContentController.addUserScript(fixedCursorUserScript)

        configuration.websiteDataStore = websiteDataStore
        configuration.userContentController = userContentController
        return configuration
    }
}
