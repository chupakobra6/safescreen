(() => {
  const storageKey = "enabledOrigins";
  const toggleEventName = "overlay-focus-guard:set-enabled";
  const refreshMessageType = "overlay-focus-guard-refresh";
  const statusMessageType = "overlay-focus-guard-status";
  const component = "content";

  function log(event, fields = {}) {
    console.info("[OverlayFocusGuard]", { component, event, ...fields });
  }

  function warn(event, fields = {}) {
    console.warn("[OverlayFocusGuard]", { component, event, ...fields });
  }

  function currentOrigin() {
    try {
      const url = new URL(window.location.href);
      if (url.protocol !== "http:" && url.protocol !== "https:") {
        return null;
      }
      return url.origin;
    } catch (_) {
      return null;
    }
  }

  function publish(enabled, origin) {
    window.dispatchEvent(new CustomEvent(toggleEventName, {
      detail: {
        enabled,
        origin
      }
    }));
    log("publish", { enabled, origin });
  }

  async function readEnabledOrigins() {
    const result = await chrome.storage.local.get({ [storageKey]: {} });
    return result[storageKey] || {};
  }

  async function sync() {
    const origin = currentOrigin();
    if (!origin) {
      publish(false, null);
      return { origin: null, enabled: false };
    }

    const enabledOrigins = await readEnabledOrigins();
    const enabled = enabledOrigins[origin] === true;
    publish(enabled, origin);
    log("sync", { enabled, origin });
    return { origin, enabled };
  }

  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName === "local" && changes[storageKey]) {
      sync().catch((error) => warn("sync-failed", { message: error.message }));
    }
  });

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type === refreshMessageType) {
      log("message-refresh");
      sync().then(sendResponse).catch((error) => {
        warn("message-refresh-failed", { message: error.message });
        sendResponse({ error: error.message });
      });
      return true;
    }

    if (message?.type === statusMessageType) {
      log("message-status");
      sync().then(sendResponse).catch((error) => {
        warn("message-status-failed", { message: error.message });
        sendResponse({ error: error.message });
      });
      return true;
    }

    return false;
  });

  window.addEventListener("pageshow", () => {
    sync().catch((error) => warn("sync-failed", { message: error.message }));
  });

  sync().catch((error) => warn("sync-failed", { message: error.message }));
})();
