namespace OverlayBrowser.Windows;

internal static class BrowserScripts
{
    internal const string FixedCursor = """
        (() => {
            const styleID = "overlay-browser-fixed-cursor-style";
            const css = `*, *::before, *::after { cursor: default !important; }`;

            function install() {
                if (document.getElementById(styleID)) return;
                const style = document.createElement("style");
                style.id = styleID;
                style.textContent = css;
                const parent = document.head || document.documentElement;
                if (parent) parent.appendChild(style);
            }

            install();
            if (document.readyState === "loading") {
                document.addEventListener("DOMContentLoaded", install, { once: true });
            }
        })();
        """;

    internal const string SilentMedia = """
        (() => {
            const selector = "audio, video";
            let observing = false;

            function mute(node) {
                if (typeof HTMLMediaElement === "undefined" || !(node instanceof HTMLMediaElement)) return;
                node.defaultMuted = true;
                node.muted = true;
                node.volume = 0;
            }

            function muteTree(root) {
                if (!(root instanceof Element)) return;
                if (root.matches(selector)) mute(root);
                root.querySelectorAll(selector).forEach(mute);
            }

            function patchPlayback() {
                if (typeof HTMLMediaElement === "undefined") return;
                const nativePlay = HTMLMediaElement.prototype.play;
                if (typeof nativePlay !== "function" || nativePlay.__overlayBrowserSilent) return;
                const silentPlay = function(...args) {
                    mute(this);
                    return nativePlay.apply(this, args);
                };
                Object.defineProperty(silentPlay, "__overlayBrowserSilent", { value: true });
                HTMLMediaElement.prototype.play = silentPlay;
            }

            function observe() {
                if (observing || !document.documentElement) return;
                const observer = new MutationObserver((mutations) => {
                    for (const mutation of mutations) {
                        if (mutation.type === "attributes") mute(mutation.target);
                        for (const node of mutation.addedNodes) muteTree(node);
                    }
                });
                observer.observe(document.documentElement, {
                    attributes: true,
                    attributeFilter: ["autoplay", "muted", "src"],
                    childList: true,
                    subtree: true
                });
                observing = true;
            }

            document.addEventListener("play", (event) => mute(event.target), true);
            document.addEventListener("volumechange", (event) => mute(event.target), true);
            patchPlayback();
            muteTree(document.documentElement);
            observe();
            if (document.readyState === "loading") {
                document.addEventListener("DOMContentLoaded", () => {
                    patchPlayback();
                    muteTree(document.documentElement);
                    observe();
                }, { once: true });
            }
        })();
        """;

    internal const string EscapeBridge = """
        (() => {
            window.addEventListener("keydown", (event) => {
                if (event.key === "Escape") {
                    window.chrome?.webview?.postMessage({ type: "overlay-escape" });
                }
            }, true);
        })();
        """;
}
