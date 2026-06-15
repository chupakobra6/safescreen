(() => {
  const storageKey = "enabledOrigins";
  const toggleEventName = "overlay-focus-guard:set-enabled";
  const refreshMessageType = "overlay-focus-guard-refresh";
  const statusMessageType = "overlay-focus-guard-status";

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
    return { origin, enabled };
  }

  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName === "local" && changes[storageKey]) {
      sync();
    }
  });

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type === refreshMessageType) {
      sync().then(sendResponse);
      return true;
    }

    if (message?.type === statusMessageType) {
      sync().then(sendResponse);
      return true;
    }

    return false;
  });

  window.addEventListener("pageshow", () => {
    sync();
  });

  sync();
})();
