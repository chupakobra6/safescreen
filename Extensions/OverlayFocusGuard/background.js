const storageKey = "enabledOrigins";
const component = "background";

function log(event, fields = {}) {
  console.info("[OverlayFocusGuard]", { component, event, ...fields });
}

function warn(event, fields = {}) {
  console.warn("[OverlayFocusGuard]", { component, event, ...fields });
}

function originFromURL(rawURL) {
  try {
    const url = new URL(rawURL || "");
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return null;
    }
    return url.origin;
  } catch (_) {
    return null;
  }
}

async function readEnabledOrigins() {
  const result = await chrome.storage.local.get({ [storageKey]: {} });
  return result[storageKey] || {};
}

async function updateBadgeForTab(tab) {
  if (!tab?.id) {
    log("badge-skip", { reason: "missing-tab-id" });
    return;
  }

  const origin = originFromURL(tab.url);
  if (!origin) {
    await chrome.action.setBadgeText({ tabId: tab.id, text: "" });
    await chrome.action.setTitle({ tabId: tab.id, title: "Overlay Focus Guard" });
    log("badge-unsupported", { tabId: tab.id });
    return;
  }

  const enabledOrigins = await readEnabledOrigins();
  const enabled = enabledOrigins[origin] === true;
  await chrome.action.setBadgeText({ tabId: tab.id, text: enabled ? "ON" : "" });
  await chrome.action.setBadgeBackgroundColor({ tabId: tab.id, color: "#15803d" });
  await chrome.action.setTitle({
    tabId: tab.id,
    title: enabled ? `Overlay Focus Guard enabled for ${origin}` : `Overlay Focus Guard disabled for ${origin}`
  });
  log("badge-updated", { tabId: tab.id, origin, enabled });
}

async function updateActiveTabBadge() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  await updateBadgeForTab(tabs[0]);
}

chrome.tabs.onActivated.addListener(async ({ tabId }) => {
  try {
    const tab = await chrome.tabs.get(tabId);
    await updateBadgeForTab(tab);
  } catch (error) {
    warn("badge-update-failed", { message: error.message });
  }
});

chrome.tabs.onUpdated.addListener((_tabId, changeInfo, tab) => {
  if (changeInfo.url || changeInfo.status === "complete") {
    updateBadgeForTab(tab);
  }
});

chrome.storage.onChanged.addListener((changes, areaName) => {
  if (areaName === "local" && changes[storageKey]) {
    updateActiveTabBadge();
  }
});

chrome.runtime.onInstalled.addListener(() => {
  log("installed");
  updateActiveTabBadge();
});
