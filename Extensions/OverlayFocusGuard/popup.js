const storageKey = "enabledOrigins";
const refreshMessageType = "overlay-focus-guard-refresh";

const originElement = document.getElementById("origin");
const statusElement = document.getElementById("status");
const toggleButton = document.getElementById("toggle");

let activeTab = null;
let activeOrigin = null;
let isEnabled = false;

function originFromURL(rawURL) {
  try {
    const url = new URL(rawURL);
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return null;
    }
    return url.origin;
  } catch (_) {
    return null;
  }
}

async function getActiveTab() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  return tabs[0] || null;
}

async function readEnabledOrigins() {
  const result = await chrome.storage.local.get({ [storageKey]: {} });
  return result[storageKey] || {};
}

async function writeEnabledOrigin(origin, enabled) {
  const enabledOrigins = await readEnabledOrigins();
  if (enabled) {
    enabledOrigins[origin] = true;
  } else {
    delete enabledOrigins[origin];
  }

  await chrome.storage.local.set({ [storageKey]: enabledOrigins });
}

async function refreshActiveTab() {
  if (!activeTab?.id) {
    return;
  }

  try {
    await chrome.tabs.sendMessage(activeTab.id, { type: refreshMessageType });
  } catch (_) {
    // The tab may not have a content script, for example chrome:// pages.
  }

  try {
    await chrome.action.setBadgeText({ tabId: activeTab.id, text: isEnabled ? "" : "ON" });
    await chrome.action.setBadgeBackgroundColor({ tabId: activeTab.id, color: "#15803d" });
  } catch (_) {}
}

function renderUnsupported() {
  originElement.textContent = activeTab?.url || "No active tab";
  statusElement.textContent = "Unsupported page";
  toggleButton.textContent = "Unavailable";
  toggleButton.disabled = true;
}

function renderSupported() {
  originElement.textContent = activeOrigin;
  statusElement.textContent = isEnabled ? "Enabled on this site" : "Disabled on this site";
  toggleButton.textContent = isEnabled ? "Disable for this site" : "Enable for this site";
  toggleButton.disabled = false;
}

async function loadState() {
  activeTab = await getActiveTab();
  activeOrigin = originFromURL(activeTab?.url || "");

  if (!activeOrigin) {
    renderUnsupported();
    return;
  }

  const enabledOrigins = await readEnabledOrigins();
  isEnabled = enabledOrigins[activeOrigin] === true;
  renderSupported();
}

toggleButton.addEventListener("click", async () => {
  if (!activeOrigin) {
    return;
  }

  toggleButton.disabled = true;
  await writeEnabledOrigin(activeOrigin, !isEnabled);
  await refreshActiveTab();
  await loadState();
});

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => {
    loadState();
  });
} else {
  loadState();
}
