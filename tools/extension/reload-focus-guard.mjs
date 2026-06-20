#!/usr/bin/env node

function argValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] || fallback : fallback;
}

function hasArg(name) {
  return process.argv.includes(name);
}

function log(event, fields = {}) {
  const parts = [
    "tool=reload-focus-guard",
    `event=${event}`,
    ...Object.entries(fields).map(([key, value]) => `${key}=${quote(String(value))}`)
  ];
  console.log(`[OverlayFocusGuardTools] ${parts.join(" ")}`);
}

function quote(value) {
  return /\s|"/.test(value) ? `"${value.replaceAll("\\", "\\\\").replaceAll("\"", "\\\"")}"` : value;
}

async function fetchJSON(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${url} returned HTTP ${response.status}`);
  }
  return response.json();
}

class CDPClient {
  constructor(webSocketURL, timeoutMs) {
    this.webSocketURL = webSocketURL;
    this.timeoutMs = timeoutMs;
    this.nextId = 1;
    this.pending = new Map();
    this.socket = null;
  }

  open() {
    return new Promise((resolve, reject) => {
      const socket = new WebSocket(this.webSocketURL);
      this.socket = socket;
      socket.addEventListener("open", resolve, { once: true });
      socket.addEventListener("error", reject, { once: true });
      socket.addEventListener("message", (event) => this.handleMessage(event.data));
      socket.addEventListener("close", () => this.rejectPending(new Error("Chrome DevTools socket closed")));
    });
  }

  close() {
    this.socket?.close();
  }

  send(method, params = {}, sessionId = undefined) {
    const id = this.nextId;
    this.nextId += 1;
    const payload = { id, method, params };
    if (sessionId) {
      payload.sessionId = sessionId;
    }

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP ${method} timed out`));
      }, this.timeoutMs);
      this.pending.set(id, { resolve, reject, timeout });
      this.socket.send(JSON.stringify(payload));
    });
  }

  handleMessage(rawMessage) {
    const message = JSON.parse(rawMessage);
    if (!message.id || !this.pending.has(message.id)) {
      return;
    }

    const pending = this.pending.get(message.id);
    this.pending.delete(message.id);
    clearTimeout(pending.timeout);

    if (message.error) {
      pending.reject(new Error(message.error.message || JSON.stringify(message.error)));
      return;
    }

    pending.resolve(message.result || {});
  }

  rejectPending(error) {
    for (const [id, pending] of this.pending) {
      this.pending.delete(id);
      clearTimeout(pending.timeout);
      pending.reject(error);
    }
  }
}

async function main() {
  if (hasArg("--help")) {
    console.log("Usage: node tools/extension/reload-focus-guard.mjs [--port 9222] [--timeout-ms 5000]");
    return;
  }

  const port = Number(argValue("--port", process.env.OVERLAY_FOCUS_GUARD_CDP_PORT || "9222"));
  const timeoutMs = Number(argValue("--timeout-ms", "5000"));
  const version = await fetchJSON(`http://127.0.0.1:${port}/json/version`);
  const client = new CDPClient(version.webSocketDebuggerUrl, timeoutMs);
  await client.open();

  try {
    const targets = await client.send("Target.getTargets");
    const worker = targets.targetInfos.find((target) => {
      return target.type === "service_worker"
        && target.url.startsWith("chrome-extension://")
        && target.url.endsWith("/background.js");
    });

    if (!worker) {
      throw new Error("Overlay Focus Guard service worker target was not found. Start Chrome with tools/extension/start-dev-chrome.mjs first.");
    }

    const attached = await client.send("Target.attachToTarget", {
      targetId: worker.targetId,
      flatten: true
    });
    await client.send("Runtime.evaluate", {
      expression: "chrome.runtime.reload(); 'reloaded';",
      returnByValue: true
    }, attached.sessionId);
    log("reloaded", { extensionWorker: worker.url, port });
  } finally {
    client.close();
  }
}

main().catch((error) => {
  console.error(`[OverlayFocusGuardTools] tool=reload-focus-guard event=failed message=${quote(error.message)}`);
  process.exitCode = 1;
});
