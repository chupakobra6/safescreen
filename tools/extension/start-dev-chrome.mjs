#!/usr/bin/env node

import { spawn } from "node:child_process";
import { access, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "../..");
const extensionRoot = path.join(repoRoot, "Extensions", "OverlayFocusGuard");
const stateRoot = path.join(repoRoot, ".state", "extension-dev-chrome");
const markerPath = path.join(repoRoot, ".state", "extension-dev-chrome.json");

function argValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] || fallback : fallback;
}

function hasArg(name) {
  return process.argv.includes(name);
}

async function fileExists(candidate) {
  try {
    await access(candidate);
    return true;
  } catch (_) {
    return false;
  }
}

async function playwrightChromiumExecutablePath() {
  try {
    const playwright = await import("playwright");
    const candidate = playwright.chromium.executablePath();
    return await fileExists(candidate) ? candidate : null;
  } catch (_) {
    return null;
  }
}

async function chromeExecutablePath() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  const playwrightPath = await playwrightChromiumExecutablePath();
  if (playwrightPath) return playwrightPath;

  const candidates = process.platform === "win32"
    ? [
        path.join(process.env.PROGRAMFILES || "", "Google", "Chrome", "Application", "chrome.exe"),
        path.join(process.env["PROGRAMFILES(X86)"] || "", "Google", "Chrome", "Application", "chrome.exe"),
        path.join(process.env.LOCALAPPDATA || "", "Google", "Chrome", "Application", "chrome.exe")
      ]
    : ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"];

  for (const candidate of candidates) {
    if (candidate && await fileExists(candidate)) return candidate;
  }

  throw new Error("Chrome/Chromium executable was not found. Run npm run playwright:install or set CHROME_PATH.");
}

function log(event, fields = {}) {
  const parts = [
    "tool=start-dev-chrome",
    `event=${event}`,
    ...Object.entries(fields).map(([key, value]) => `${key}=${quote(String(value))}`)
  ];
  console.log(`[OverlayFocusGuardTools] ${parts.join(" ")}`);
}

function quote(value) {
  return /\s|"/.test(value) ? `"${value.replaceAll("\\", "\\\\").replaceAll("\"", "\\\"")}"` : value;
}

async function probeCDP(port, timeoutMs = 500) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/version`, {
      signal: controller.signal
    });
    return response.ok ? await response.json() : null;
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

async function waitForCDP(port, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const version = await probeCDP(port);
    if (version?.webSocketDebuggerUrl) {
      return version;
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`Chrome DevTools endpoint did not become ready on 127.0.0.1:${port}`);
}

async function main() {
  if (hasArg("--help")) {
    console.log(`Usage: node tools/extension/start-dev-chrome.mjs [--port 9222] [--url https://example.com]`);
    return;
  }

  const port = Number(argValue("--port", process.env.OVERLAY_FOCUS_GUARD_CDP_PORT || "9222"));
  const url = argValue("--url", "about:blank");
  const existing = await probeCDP(port);
  if (existing?.webSocketDebuggerUrl) {
    log("already-running", { port, endpoint: existing.webSocketDebuggerUrl });
    return;
  }

  await mkdir(stateRoot, { recursive: true });
  await mkdir(path.dirname(markerPath), { recursive: true });

  const args = [
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${stateRoot}`,
    `--disable-extensions-except=${extensionRoot}`,
    `--load-extension=${extensionRoot}`,
    "--disable-features=DisableLoadExtensionCommandLineSwitch",
    "--no-first-run",
    "--no-default-browser-check",
    url
  ];

  const executablePath = await chromeExecutablePath();
  const child = spawn(executablePath, args, {
    detached: true,
    stdio: "ignore",
    windowsHide: true
  });
  child.unref();

  await waitForCDP(port);
  const marker = {
    pid: child.pid,
    port,
    executablePath,
    profile: stateRoot,
    extension: extensionRoot,
    startedAt: new Date().toISOString()
  };
  await writeFile(markerPath, `${JSON.stringify(marker, null, 2)}\n`);
  log("started", marker);
}

main().catch((error) => {
  console.error(`[OverlayFocusGuardTools] tool=start-dev-chrome event=failed message=${quote(error.message)}`);
  process.exitCode = 1;
});
