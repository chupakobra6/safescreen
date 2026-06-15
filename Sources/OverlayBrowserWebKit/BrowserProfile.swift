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
    public static let silentMediaUserScriptSource = """
    (() => {
        const mediaSelector = "audio, video";
        let isWatchingMedia = false;

        function muteMedia(node) {
            if (typeof HTMLMediaElement === "undefined" || !(node instanceof HTMLMediaElement)) {
                return;
            }

            if (node.defaultMuted !== true) {
                node.defaultMuted = true;
            }

            if (node.muted !== true) {
                node.muted = true;
            }

            if (node.volume !== 0) {
                node.volume = 0;
            }
        }

        function muteSubtree(root) {
            if (!(root instanceof Element)) {
                return;
            }

            if (root.matches(mediaSelector)) {
                muteMedia(root);
            }

            root.querySelectorAll(mediaSelector).forEach(muteMedia);
        }

        function patchMediaPlayback() {
            if (typeof HTMLMediaElement === "undefined") {
                return;
            }

            const nativePlay = HTMLMediaElement.prototype.play;
            if (typeof nativePlay !== "function" || nativePlay.__overlayBrowserSilent) {
                return;
            }

            const silentPlay = function(...args) {
                muteMedia(this);
                return nativePlay.apply(this, args);
            };

            Object.defineProperty(silentPlay, "__overlayBrowserSilent", { value: true });
            HTMLMediaElement.prototype.play = silentPlay;
        }

        function patchAudioContext(name) {
            const NativeAudioContext = window[name];
            if (typeof NativeAudioContext !== "function" || NativeAudioContext.__overlayBrowserSilent) {
                return;
            }

            const nativeResume = NativeAudioContext.prototype.resume;
            if (typeof nativeResume === "function" && !nativeResume.__overlayBrowserSilent) {
                const silentResume = function() {
                    if (typeof this.suspend === "function") {
                        return this.suspend().catch(() => {});
                    }

                    return Promise.resolve();
                };

                Object.defineProperty(silentResume, "__overlayBrowserSilent", { value: true });
                NativeAudioContext.prototype.resume = silentResume;
            }

            const SilentAudioContext = function(...args) {
                const context = new NativeAudioContext(...args);
                if (typeof context.suspend === "function") {
                    context.suspend().catch(() => {});
                }
                return context;
            };

            SilentAudioContext.prototype = NativeAudioContext.prototype;
            Object.setPrototypeOf(SilentAudioContext, NativeAudioContext);
            Object.defineProperty(SilentAudioContext, "__overlayBrowserSilent", { value: true });
            window[name] = SilentAudioContext;
        }

        function watchMediaChanges() {
            if (isWatchingMedia || !document.documentElement) {
                return;
            }

            const observer = new MutationObserver((mutations) => {
                for (const mutation of mutations) {
                    if (mutation.type === "attributes") {
                        muteMedia(mutation.target);
                    }

                    for (const node of mutation.addedNodes) {
                        muteSubtree(node);
                    }
                }
            });

            observer.observe(document.documentElement, {
                attributes: true,
                attributeFilter: ["autoplay", "muted", "src"],
                childList: true,
                subtree: true
            });
            isWatchingMedia = true;
        }

        document.addEventListener("play", (event) => {
            muteMedia(event.target);
        }, true);

        document.addEventListener("volumechange", (event) => {
            muteMedia(event.target);
        }, true);

        patchMediaPlayback();
        patchAudioContext("AudioContext");
        patchAudioContext("webkitAudioContext");
        muteSubtree(document.documentElement);
        watchMediaChanges();

        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", () => {
                patchMediaPlayback();
                patchAudioContext("AudioContext");
                patchAudioContext("webkitAudioContext");
                muteSubtree(document.documentElement);
                watchMediaChanges();
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
        let silentMediaUserScript = WKUserScript(
            source: silentMediaUserScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        userContentController.addUserScript(fixedCursorUserScript)
        userContentController.addUserScript(silentMediaUserScript)

        configuration.websiteDataStore = websiteDataStore
        configuration.userContentController = userContentController
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        return configuration
    }
}
