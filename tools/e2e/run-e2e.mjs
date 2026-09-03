#!/usr/bin/env node

import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { copyFile, mkdir, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "../..");
const extensionRoot = path.join(repoRoot, "Extensions", "OverlayFocusGuard");
const stateRoot = path.join(repoRoot, ".state", "e2e");
const logRoot = path.join(repoRoot, "logs");
const overlayE2EBundleIdentifier = "com.igor.safescreen.overlay-browser.e2e";
const overlayE2EApplication = path.join(stateRoot, "Overlay Browser E2E.app");
const overlayE2EExecutable = path.join(overlayE2EApplication, "Contents", "MacOS", "OverlayBrowser");
const overlayE2EProfile = path.join(
  process.env.HOME,
  "Library",
  "WebKit",
  overlayE2EBundleIdentifier
);

class BlockedError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = "BlockedError";
    this.details = details;
  }
}

class Reporter {
  constructor() {
    this.startedAt = new Date();
    this.results = [];
    this.lines = [];
  }

  log(message) {
    const line = `[e2e] ${new Date().toISOString()} ${message}`;
    this.lines.push(line);
    console.log(line);
  }

  async step(name, fn) {
    const startedAt = Date.now();
    this.log(`start ${name}`);
    try {
      const details = await fn();
      const result = { name, status: "pass", durationMs: Date.now() - startedAt, details: details || {} };
      this.results.push(result);
      this.log(`pass ${name} ${result.durationMs}ms`);
      return result;
    } catch (error) {
      const status = error instanceof BlockedError ? "blocked" : "fail";
      const result = {
        name,
        status,
        durationMs: Date.now() - startedAt,
        error: error.message,
        details: error.details || {}
      };
      this.results.push(result);
      this.log(`${status} ${name} ${result.durationMs}ms ${error.message}`);
      return result;
    }
  }

  async writeReports() {
    await mkdir(logRoot, { recursive: true });
    const stamp = this.startedAt.toISOString().replace(/[:.]/g, "-");
    const payload = {
      startedAt: this.startedAt.toISOString(),
      finishedAt: new Date().toISOString(),
      results: this.results
    };
    const jsonPath = path.join(logRoot, `e2e-${stamp}.json`);
    const logPath = path.join(logRoot, `e2e-${stamp}.log`);
    await writeFile(jsonPath, `${JSON.stringify(payload, null, 2)}\n`);
    await writeFile(logPath, `${this.lines.join("\n")}\n`);
    this.log(`wrote ${path.relative(repoRoot, jsonPath)}`);
    this.log(`wrote ${path.relative(repoRoot, logPath)}`);
    return { jsonPath, logPath };
  }

  exitCode() {
    return this.results.some((result) => result.status === "fail") ? 1 : 0;
  }
}

function parseArgs() {
  const args = new Set(process.argv.slice(2));
  const all = args.has("--all") || args.size === 0;
  return {
    app: all || args.has("--app"),
    extension: all || args.has("--extension"),
    screenShare: all || args.has("--screen-share"),
    reloadExtension: all || args.has("--reload-extension"),
    keepChrome: args.has("--keep-chrome") || process.env.E2E_KEEP_CHROME === "1"
  };
}

function run(command, args = [], options = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: repoRoot,
      env: { ...process.env, ...(options.env || {}) },
      stdio: ["ignore", "pipe", "pipe"]
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("close", (status) => {
      resolve({ status, stdout, stderr });
    });
  });
}

async function mustRun(command, args = [], options = {}) {
  const result = await run(command, args, options);
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed with ${result.status}\n${result.stdout}\n${result.stderr}`);
  }
  return result;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function frontmostApplicationInfo() {
  const script = `
import AppKit
import Foundation

let application = NSWorkspace.shared.frontmostApplication
let payload: [String: Any] = [
    "pid": application?.processIdentifier ?? -1,
    "bundleIdentifier": application?.bundleIdentifier ?? "",
    "name": application?.localizedName ?? ""
]
let data = try! JSONSerialization.data(withJSONObject: payload)
print(String(data: data, encoding: .utf8)!)
`;
  const result = await mustRun("swift", ["-e", script]);
  return JSON.parse(result.stdout);
}

async function activateApplication(pid) {
  const script = `
import AppKit
import Foundation

let pid = Int32(ProcessInfo.processInfo.environment["TARGET_PID"] ?? "") ?? -1
guard let application = NSRunningApplication(processIdentifier: pid),
      application.activate(options: [.activateIgnoringOtherApps]) else {
    fputs("failed to activate pid \\(pid)\\n", stderr)
    exit(2)
}
`;
  await mustRun("swift", ["-e", script], { env: { TARGET_PID: String(pid) } });
}

async function runningApplicationInfo(pid) {
  const script = `
import AppKit
import Foundation

let pid = Int32(ProcessInfo.processInfo.environment["TARGET_PID"] ?? "") ?? -1
let application = NSRunningApplication(processIdentifier: pid)
let payload: [String: Any] = [
    "found": application != nil,
    "activationPolicy": application?.activationPolicy.rawValue ?? -1,
    "bundleIdentifier": application?.bundleIdentifier ?? "",
    "name": application?.localizedName ?? ""
]
let data = try! JSONSerialization.data(withJSONObject: payload)
print(String(data: data, encoding: .utf8)!)
`;
  const result = await mustRun("swift", ["-e", script], { env: { TARGET_PID: String(pid) } });
  return JSON.parse(result.stdout);
}

async function terminateApplication(pid) {
  const script = `
import AppKit
import Foundation

let pid = Int32(ProcessInfo.processInfo.environment["TARGET_PID"] ?? "") ?? -1
guard let application = NSRunningApplication(processIdentifier: pid), application.terminate() else {
    fputs("failed to terminate pid \\(pid)\\n", stderr)
    exit(2)
}
`;
  await mustRun("swift", ["-e", script], { env: { TARGET_PID: String(pid) } });
}

async function waitForOutput(application, predicate, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const output = application.output();
    if (predicate(output)) return output;
    await sleep(100);
  }
  throw new Error("timed out waiting for application output");
}

async function waitForProcessExit(pid, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      process.kill(pid, 0);
    } catch {
      return;
    }
    await sleep(100);
  }
  throw new Error(`process ${pid} did not exit`);
}

let syntheticInputStatusPromise = null;

async function syntheticInputStatus() {
  if (syntheticInputStatusPromise) {
    return syntheticInputStatusPromise;
  }

  syntheticInputStatusPromise = (async () => {
    const script = `
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

func post(_ keyCode: Int, _ keyDown: Bool) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: keyDown)!
    event.post(tap: .cghidEventTap)
}

let trusted = AXIsProcessTrusted()
var syntheticModifierStateVisible = false
for _ in 0..<3 {
    post(kVK_Option, true)
    usleep(180_000)
    syntheticModifierStateVisible = CGEventSource.keyState(.hidSystemState, key: CGKeyCode(kVK_Option))
    post(kVK_Option, false)
    if syntheticModifierStateVisible { break }
    usleep(120_000)
}

let payload: [String: Any] = [
    "accessibilityTrusted": trusted,
    "syntheticModifierStateVisible": syntheticModifierStateVisible
]
let data = try! JSONSerialization.data(withJSONObject: payload)
print(String(data: data, encoding: .utf8)!)
`;
    const result = await mustRun("swift", ["-e", script]);
    return JSON.parse(result.stdout);
  })();

  return syntheticInputStatusPromise;
}

async function startLocalServer() {
  const events = [];
  const server = createServer(async (request, response) => {
    const url = new URL(request.url, "http://127.0.0.1");
    if (request.method === "POST" && url.pathname === "/api/events") {
      let body = "";
      request.on("data", (chunk) => {
        body += chunk;
      });
      request.on("end", () => {
        try {
          events.push({ at: Date.now(), ...JSON.parse(body) });
          response.writeHead(204);
          response.end();
        } catch (error) {
          response.writeHead(400);
          response.end(String(error));
        }
      });
      return;
    }

    const page = pages[url.pathname];
    if (page) {
      response.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      response.end(page);
      return;
    }

    response.writeHead(404);
    response.end("not found");
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  return {
    origin: `http://127.0.0.1:${port}`,
    events,
    close: () => new Promise((resolve) => server.close(resolve))
  };
}

const pages = {
  "/clipboard.html": `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Overlay Clipboard E2E</title>
  <style>
    html, body { margin: 0; height: 100%; font: 16px system-ui, sans-serif; }
    #target { box-sizing: border-box; min-height: 100vh; padding: 24px; outline: none; }
  </style>
</head>
<body>
  <div id="target" contenteditable="true" spellcheck="false">READY</div>
  <script>
    const target = document.getElementById("target");
    function report(payload) {
      fetch("/api/events", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ page: "clipboard", ...payload })
      }).catch(() => {});
    }
    target.addEventListener("paste", (event) => {
      const items = [...event.clipboardData.items].map((item) => item.type || item.kind);
      report({ type: "paste", text: event.clipboardData.getData("text/plain"), items });
    });
    target.addEventListener("input", () => {
      report({ type: "input", text: target.innerText, html: target.innerHTML });
    });
    window.addEventListener("load", () => {
      target.focus();
      report({ type: "ready" });
    });
  </script>
</body>
</html>`,
  "/focus.html": `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Overlay Focus Guard E2E</title>
</head>
<body>
  <main>
    <h1>Focus Guard E2E</h1>
    <pre id="status"></pre>
  </main>
  <script>
    const trackedEvents = ["blur", "visibilitychange", "webkitvisibilitychange", "pagehide", "freeze"];
    window.__focusStats = { events: [] };
    function snapshot() {
      return {
        hidden: document.hidden,
        visibilityState: document.visibilityState,
        hasFocus: document.hasFocus(),
        events: [...window.__focusStats.events]
      };
    }
    function report(payload) {
      fetch("/api/events", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ page: "focus", ...payload })
      }).catch(() => {});
    }
    for (const eventName of trackedEvents) {
      window.addEventListener(eventName, () => {
        window.__focusStats.events.push({ target: "window", eventName });
        report({ type: "event", target: "window", eventName, snapshot: snapshot() });
      });
      document.addEventListener(eventName, () => {
        window.__focusStats.events.push({ target: "document", eventName });
        report({ type: "event", target: "document", eventName, snapshot: snapshot() });
      });
    }
    window.__focusSnapshot = snapshot;
    window.__dispatchTrackedEvents = () => {
      const before = window.__focusStats.events.length;
      for (const eventName of trackedEvents) {
        window.dispatchEvent(new Event(eventName));
        document.dispatchEvent(new Event(eventName));
      }
      const after = window.__focusStats.events.length;
      return { before, after, delta: after - before, snapshot: snapshot() };
    };
    window.addEventListener("load", () => {
      document.getElementById("status").textContent = JSON.stringify(snapshot(), null, 2);
      report({ type: "ready", snapshot: snapshot() });
    });
  </script>
</body>
</html>`,
  "/persistence.html": `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Overlay Storage Persistence E2E</title>
</head>
<body>
  <main>Storage persistence test</main>
  <script>
    const params = new URLSearchParams(location.search);
    const mode = params.get("mode") || "read";
    const token = params.get("token") || "";
    if (mode === "write") {
      document.cookie = "overlay_e2e=" + encodeURIComponent(token) + "; Path=/; Max-Age=3600; SameSite=Lax";
      localStorage.setItem("overlay_e2e", token);
    }
    fetch("/api/events", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        page: "persistence",
        type: "state",
        mode,
        token,
        cookie: document.cookie,
        localStorageValue: localStorage.getItem("overlay_e2e")
      })
    }).catch(() => {});
  </script>
</body>
</html>`,
  "/popup.html": `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Overlay Popup Navigation E2E</title>
</head>
<body>
  <a id="open" href="/popup-target.html" target="_blank">Open target</a>
  <script>
    window.addEventListener("load", () => document.getElementById("open").click());
  </script>
</body>
</html>`,
  "/popup-target.html": `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Overlay Popup Target E2E</title>
</head>
<body>
  <main>Popup target loaded in current tab</main>
  <script>
    fetch("/api/events", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ page: "popup", type: "target-loaded" })
    }).catch(() => {});
  </script>
</body>
</html>`,
  "/screen-share.html": `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Screen Share E2E</title>
  <style>video, canvas { width: 480px; max-width: 100%; border: 1px solid #ccc; }</style>
</head>
<body>
  <button id="start">Start display capture</button>
  <video id="video" autoplay muted playsinline></video>
  <canvas id="canvas"></canvas>
  <pre id="status">idle</pre>
  <script>
    const video = document.getElementById("video");
    const canvas = document.getElementById("canvas");
    const statusElement = document.getElementById("status");
    function setStatus(value) {
      statusElement.textContent = JSON.stringify(value, null, 2);
    }
    async function startCapture() {
      if (video.srcObject) return video.srcObject;
      const stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
      video.srcObject = stream;
      await video.play();
      await new Promise((resolve) => {
        if (video.videoWidth > 0) resolve();
        else video.addEventListener("loadedmetadata", resolve, { once: true });
      });
      return stream;
    }
    window.__startDisplayCapture = async () => {
      try {
        const stream = await startCapture();
        const track = stream.getVideoTracks()[0];
        return { ok: true, settings: track ? track.getSettings() : {} };
      } catch (error) {
        return { ok: false, name: error.name, message: error.message };
      }
    };
    window.__sampleDisplayCapture = async ({ x, y, screenWidth, screenHeight }) => {
      try {
        const stream = await startCapture();
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        const context = canvas.getContext("2d", { willReadFrequently: true });
        await new Promise((resolve) => setTimeout(resolve, 500));
        context.drawImage(video, 0, 0, canvas.width, canvas.height);
        const sampleX = Math.max(0, Math.min(canvas.width - 1, Math.round(x * canvas.width / screenWidth)));
        const sampleY = Math.max(0, Math.min(canvas.height - 1, Math.round(y * canvas.height / screenHeight)));
        const pixel = [...context.getImageData(sampleX, sampleY, 1, 1).data];
        const track = stream.getVideoTracks()[0];
        const result = {
          ok: true,
          pixel,
          sampleX,
          sampleY,
          videoWidth: canvas.width,
          videoHeight: canvas.height,
          settings: track ? track.getSettings() : {}
        };
        setStatus(result);
        return result;
      } catch (error) {
        const result = { ok: false, name: error.name, message: error.message };
        setStatus(result);
        return result;
      }
    };
    document.getElementById("start").addEventListener("click", () => {
      window.__sampleDisplayCapture({ x: screen.width / 2, y: screen.height / 2, screenWidth: screen.width, screenHeight: screen.height });
    });
  </script>
</body>
</html>`,
  "/overlay-marker.html": `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Overlay Marker E2E</title>
  <style>
    html, body { margin: 0; width: 100%; height: 100%; background: rgb(255, 0, 255); color: white; font: 28px system-ui, sans-serif; }
    body { display: grid; place-items: center; }
  </style>
</head>
<body>OVERLAY_SECRET_MARKER</body>
</html>`
};

async function waitForServerEvent(server, predicate, timeoutMs = 4000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const event = server.events.find(predicate);
    if (event) return event;
    await sleep(100);
  }
  throw new Error("timed out waiting for local page event");
}

async function waitForFile(filePath, timeoutMs = 3000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const details = await stat(filePath);
      if (details.size > 0) return details;
    } catch {
      // The app writes the snapshot asynchronously after presenting the toast.
    }
    await sleep(100);
  }
  throw new Error(`timed out waiting for file ${filePath}`);
}

async function imageCornerInfo(filePath) {
  const script = `
import AppKit
import Foundation

let path = ProcessInfo.processInfo.environment["IMAGE_PATH"] ?? ""
guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
      let bitmap = NSBitmapImageRep(data: data) else {
    fputs("Unable to read PNG at \\(path)\\n", stderr)
    exit(2)
}

let points = [
    NSPoint(x: 0, y: 0),
    NSPoint(x: bitmap.pixelsWide - 1, y: 0),
    NSPoint(x: 0, y: bitmap.pixelsHigh - 1),
    NSPoint(x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1)
]
let alphas = points.map { bitmap.colorAt(x: Int($0.x), y: Int($0.y))?.alphaComponent ?? 1 }
let payload: [String: Any] = [
    "width": bitmap.pixelsWide,
    "height": bitmap.pixelsHigh,
    "cornerAlphas": alphas
]
let payloadData = try! JSONSerialization.data(withJSONObject: payload)
print(String(data: payloadData, encoding: .utf8)!)
`;
  const result = await mustRun("swift", ["-e", script], { env: { IMAGE_PATH: filePath } });
  return JSON.parse(result.stdout);
}

async function systemScreenCaptureSamples(filePath, points) {
  await rm(filePath, { force: true });
  const capture = await run("screencapture", ["-x", filePath]);
  if (capture.status !== 0) {
    throw new BlockedError("macOS did not grant system screen capture", {
      stderr: capture.stderr,
      status: capture.status
    });
  }
  await waitForFile(filePath);

  const script = `
import AppKit
import CoreGraphics
import Foundation

let path = ProcessInfo.processInfo.environment["IMAGE_PATH"] ?? ""
let pointsData = (ProcessInfo.processInfo.environment["SAMPLE_POINTS"] ?? "[]").data(using: .utf8)!
guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
      let bitmap = NSBitmapImageRep(data: data),
      let points = try? JSONSerialization.jsonObject(with: pointsData) as? [[String: Any]] else {
    fputs("Unable to read screen capture inputs\\n", stderr)
    exit(2)
}

let displayBounds = CGDisplayBounds(CGMainDisplayID())
let scaleX = CGFloat(bitmap.pixelsWide) / displayBounds.width
let scaleY = CGFloat(bitmap.pixelsHigh) / displayBounds.height
var samples: [String: [Int]] = [:]
for point in points {
    guard let name = point["name"] as? String,
          let x = point["x"] as? NSNumber,
          let y = point["y"] as? NSNumber else { continue }
    let pixelX = min(bitmap.pixelsWide - 1, max(0, Int(round(x.doubleValue * scaleX))))
    let pixelFromTop = min(bitmap.pixelsHigh - 1, max(0, Int(round(y.doubleValue * scaleY))))
    let pixelY = bitmap.pixelsHigh - 1 - pixelFromTop
    let color = bitmap.colorAt(x: pixelX, y: pixelY)?.usingColorSpace(.deviceRGB)
    samples[name] = [
        Int(round((color?.redComponent ?? 0) * 255)),
        Int(round((color?.greenComponent ?? 0) * 255)),
        Int(round((color?.blueComponent ?? 0) * 255)),
        Int(round((color?.alphaComponent ?? 0) * 255))
    ]
}

let payload: [String: Any] = [
    "imageWidth": bitmap.pixelsWide,
    "imageHeight": bitmap.pixelsHigh,
    "samples": samples
]
let payloadData = try! JSONSerialization.data(withJSONObject: payload)
print(String(data: payloadData, encoding: .utf8)!)
`;
  const result = await mustRun("swift", ["-e", script], {
    env: {
      IMAGE_PATH: filePath,
      SAMPLE_POINTS: JSON.stringify(points)
    }
  });
  return JSON.parse(result.stdout);
}

async function startOverlay(url, env = {}) {
  await mustRun("swift", ["build"]);
  await prepareOverlayE2EApplication();
  const args = [overlayE2EExecutable, "--overlay-helper"];
  if (url) args.push(url);
  return startApplicationProcess(args, env, true);
}

async function startDockHost() {
  await mustRun("swift", ["build"]);
  await prepareOverlayE2EApplication();
  return startApplicationProcess([overlayE2EExecutable], {}, false);
}

async function startApplicationProcess(args, env, waitForWindow) {
  const child = spawn(args[0], args.slice(1), {
    cwd: repoRoot,
    env: { ...process.env, ...env },
    stdio: ["ignore", "pipe", "pipe"]
  });
  let stdout = "";
  let stderr = "";
  let closed = false;
  const closePromise = new Promise((resolve) => {
    child.once("close", (status, signal) => {
      closed = true;
      resolve({ status, signal });
    });
  });
  child.stdout.on("data", (chunk) => {
    stdout += chunk;
  });
  child.stderr.on("data", (chunk) => {
    stderr += chunk;
  });
  try {
    if (waitForWindow) {
      await waitForOverlayWindow(child.pid);
    }
  } catch (error) {
    if (!closed && !child.killed) child.kill();
    await closePromise;
    throw new Error(`${error.message}\n${stderr}`);
  }
  return {
    pid: child.pid,
    child,
    output: () => ({ stdout, stderr }),
    stop: async () => {
      if (!closed && !child.killed) child.kill();
      await closePromise;
    }
  };
}

async function waitForOverlayWindow(pid, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  let latest = { found: false };
  while (Date.now() < deadline) {
    latest = await windowInfo(pid);
    if (latest.found) return latest;
    await sleep(100);
  }
  throw new Error(`overlay window not ready for pid ${pid}: ${JSON.stringify(latest)}`);
}

async function prepareOverlayE2EApplication() {
  const contents = path.join(overlayE2EApplication, "Contents");
  const macOSDirectory = path.join(contents, "MacOS");
  const resourcesDirectory = path.join(contents, "Resources");
  await rm(overlayE2EApplication, { recursive: true, force: true });
  await mkdir(macOSDirectory, { recursive: true });
  await mkdir(resourcesDirectory, { recursive: true });
  await copyFile(path.join(repoRoot, ".build", "debug", "OverlayBrowser"), overlayE2EExecutable);
  await copyFile(path.join(repoRoot, "Packaging", "macOS", "Info.plist"), path.join(contents, "Info.plist"));
  await copyFile(
    path.join(repoRoot, "Packaging", "macOS", "AppIcon.icns"),
    path.join(resourcesDirectory, "AppIcon.icns")
  );
  await mustRun("plutil", [
    "-replace",
    "CFBundleIdentifier",
    "-string",
    overlayE2EBundleIdentifier,
    path.join(contents, "Info.plist")
  ]);
  await mustRun("plutil", [
    "-replace",
    "CFBundleDisplayName",
    "-string",
    "OverlayBrowser",
    path.join(contents, "Info.plist")
  ]);
  await mustRun("codesign", ["--force", "--sign", "-", "--timestamp=none", overlayE2EApplication]);
}

async function windowInfo(pid, windowName = "Overlay Browser") {
  const script = `
import AppKit
import CoreGraphics
import Foundation

let targetPID = Int(ProcessInfo.processInfo.environment["OVERLAY_PID"] ?? "") ?? -1
let targetWindowName = ProcessInfo.processInfo.environment["OVERLAY_WINDOW_NAME"] ?? ""
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.filter {
    ($0[kCGWindowOwnerName as String] as? String) == "OverlayBrowser"
        && ($0[kCGWindowOwnerPID as String] as? Int) == targetPID
        && ($0[kCGWindowName as String] as? String) == targetWindowName
}

func emit(_ object: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: object)
    print(String(data: data, encoding: .utf8)!)
}

guard let window = matches.first else {
    emit(["found": false])
    exit(0)
}

let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
let runningApplication = NSRunningApplication(processIdentifier: pid_t(targetPID))
emit([
    "found": true,
    "name": window[kCGWindowName as String] as? String ?? "",
    "sharingState": window[kCGWindowSharingState as String] as? Int ?? -1,
    "activationPolicy": runningApplication?.activationPolicy.rawValue ?? -1,
    "bounds": bounds
])
`;
  const result = await mustRun("swift", ["-e", script], {
    env: {
      OVERLAY_PID: String(pid),
      OVERLAY_WINDOW_NAME: windowName
    }
  });
  return JSON.parse(result.stdout);
}

async function postModifierHotKey(side) {
  const script = `
import Carbon
import CoreGraphics
import Foundation

let side = ProcessInfo.processInfo.environment["HOTKEY_SIDE"] ?? "left"
let optionKey = side == "right" ? kVK_RightOption : kVK_Option
let shiftKey = side == "right" ? kVK_RightShift : kVK_Shift

func post(_ keyCode: Int, _ keyDown: Bool) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: keyDown)!
    event.post(tap: .cghidEventTap)
}

post(optionKey, true)
usleep(60_000)
post(shiftKey, true)
usleep(220_000)
post(shiftKey, false)
usleep(40_000)
post(optionKey, false)
`;
  await mustRun("swift", ["-e", script], { env: { HOTKEY_SIDE: side } });
}

async function clickScreenPoint(x, y) {
  const script = `
import CoreGraphics
import Foundation

let x = Double(ProcessInfo.processInfo.environment["CLICK_X"] ?? "") ?? 0
let y = Double(ProcessInfo.processInfo.environment["CLICK_Y"] ?? "") ?? 0
let point = CGPoint(x: x, y: y)
for type in [CGEventType.leftMouseDown, CGEventType.leftMouseUp] {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!
    event.post(tap: .cghidEventTap)
}
`;
  await mustRun("swift", ["-e", script], {
    env: { CLICK_X: String(x), CLICK_Y: String(y) }
  });
}

async function pasteTextIntoOverlay(pid, text) {
  const script = `
import AppKit
import Carbon
import CoreGraphics
import Foundation

let text = ProcessInfo.processInfo.environment["PASTE_TEXT"] ?? ""
let targetPID = Int(ProcessInfo.processInfo.environment["OVERLAY_PID"] ?? "") ?? -1
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
guard let window = windows.first(where: {
    ($0[kCGWindowOwnerName as String] as? String) == "OverlayBrowser"
        && ($0[kCGWindowOwnerPID as String] as? Int) == targetPID
        && ($0[kCGWindowName as String] as? String) == "Overlay Browser"
}) else {
    fputs("Overlay window not found\\n", stderr)
    exit(2)
}
let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
let x = bounds["X"] as? CGFloat ?? 0
let y = bounds["Y"] as? CGFloat ?? 0
let width = bounds["Width"] as? CGFloat ?? 0
let height = bounds["Height"] as? CGFloat ?? 0
let point = CGPoint(x: x + width / 2, y: y + height / 2)

NSPasteboard.general.clearContents()
NSPasteboard.general.setString(text, forType: .string)

func mouse(_ type: CGEventType) {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!
    event.post(tap: .cghidEventTap)
}
func key(_ keyCode: Int, _ keyDown: Bool) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: keyDown)!
    event.post(tap: .cghidEventTap)
}

mouse(.leftMouseDown)
mouse(.leftMouseUp)
usleep(500_000)
key(kVK_Command, true)
usleep(20_000)
key(kVK_ANSI_V, true)
usleep(40_000)
key(kVK_ANSI_V, false)
usleep(20_000)
key(kVK_Command, false)
`;
  await mustRun("swift", ["-e", script], { env: { OVERLAY_PID: String(pid), PASTE_TEXT: text } });
}

async function testUnitAndExtensionSyntax() {
  if (process.platform === "darwin") {
    await mustRun("swift", ["test"]);
  } else if (process.platform === "win32") {
    await mustRun("dotnet", [
      "test",
      "Windows/tests/OverlayBrowser.Windows.Tests/OverlayBrowser.Windows.Tests.csproj",
      "--configuration",
      "Release"
    ]);
  }
  await mustRun("node", ["--check", "Extensions/OverlayFocusGuard/page-guard.js"]);
  await mustRun("node", ["--check", "Extensions/OverlayFocusGuard/content.js"]);
  await mustRun("node", ["--check", "Extensions/OverlayFocusGuard/popup.js"]);
  await mustRun("node", ["--check", "Extensions/OverlayFocusGuard/background.js"]);
  await mustRun("node", ["--check", "tools/extension/start-dev-chrome.mjs"]);
  await mustRun("node", ["--check", "tools/extension/reload-focus-guard.mjs"]);
  await mustRun("node", ["-e", "JSON.parse(require('fs').readFileSync('Extensions/OverlayFocusGuard/manifest.json', 'utf8'));"]);
  return {};
}

async function testOverlaySmoke() {
  const toastSnapshotPath = path.join(stateRoot, "hotkey-toast.png");
  await rm(toastSnapshotPath, { force: true });
  const overlay = await startOverlay(undefined, {
    OVERLAY_TOAST_SNAPSHOT_PATH: toastSnapshotPath
  });
  try {
    const info = await windowInfo(overlay.pid);
    if (!info.found) throw new Error("overlay window not found");
    if (info.sharingState !== 0) throw new Error(`expected sharingState=0, got ${info.sharingState}`);
    if (Number(info.bounds.Width) < 400 || Number(info.bounds.Height) < 800) {
      throw new Error(`unexpected default overlay bounds ${JSON.stringify(info.bounds)}`);
    }
    if (info.activationPolicy !== 1) {
      throw new Error(`expected accessory helper activation policy, got ${info.activationPolicy}`);
    }

    const separateToast = await windowInfo(overlay.pid, "Overlay Browser Notification: hotkeys");
    if (separateToast.found) throw new Error("startup hotkey reminder opened a separate window");
    const snapshot = await waitForFile(toastSnapshotPath);
    const snapshotImage = await imageCornerInfo(toastSnapshotPath);
    if (snapshotImage.width < 380 || snapshotImage.height < 104) {
      throw new Error(`unexpected embedded toast snapshot size ${JSON.stringify(snapshotImage)}`);
    }
    if (Math.max(...snapshotImage.cornerAlphas) > 0.15) {
      throw new Error(`embedded toast corners are not transparent: ${JSON.stringify(snapshotImage)}`);
    }

    let logs = overlay.output().stderr;
    if (!logs.includes("event=initial-url") || !logs.includes("https://chatgpt.com/")) {
      throw new Error("default ChatGPT navigation was not logged");
    }
    if (!logs.includes("category=notification event=shown container=browser-window id=hotkeys")) {
      throw new Error("startup hotkey reminder was not shown inside the browser window");
    }

    await sleep(6200);
    logs = overlay.output().stderr;
    if (!logs.includes("category=notification event=dismissed id=hotkeys reason=timeout")) {
      throw new Error("startup hotkey toast timeout was not logged");
    }

    return {
      pid: overlay.pid,
      window: info,
      embeddedToast: true,
      separateToastWindow: separateToast.found,
      toastSnapshotBytes: snapshot.size,
      toastSnapshotImage: snapshotImage
    };
  } finally {
    await overlay.stop();
  }
}

async function testSystemScreenCapturePrivacy(server) {
  const activeCapturePath = path.join(stateRoot, "system-capture-overlay-visible.png");
  const hiddenCapturePath = path.join(stateRoot, "system-capture-overlay-closed.png");
  const overlay = await startOverlay(`${server.origin}/overlay-marker.html`);
  let stopped = false;
  try {
    const info = await windowInfo(overlay.pid);
    if (!info.found) throw new Error("overlay window not found for system capture");
    await waitForOutput(
      overlay,
      ({ stderr }) => stderr.includes("category=notification event=shown container=browser-window id=hotkeys")
    );

    const bounds = info.bounds;
    const points = [
      {
        name: "browserCenter",
        x: Number(bounds.X) + Number(bounds.Width) / 2,
        y: Number(bounds.Y) + Number(bounds.Height) / 2
      },
      {
        name: "toastCenter",
        x: Number(bounds.X) + Number(bounds.Width) - 202,
        y: Number(bounds.Y) + 92
      }
    ];
    const visible = await systemScreenCaptureSamples(activeCapturePath, points);
    const [red, green, blue] = visible.samples.browserCenter;
    if (red > 220 && green < 40 && blue > 220) {
      throw new Error("overlay marker was visible in macOS system screen capture");
    }

    const foregroundBeforeClose = await frontmostApplicationInfo();
    await clickScreenPoint(
      Number(bounds.X) + Number(bounds.Width) - 33,
      Number(bounds.Y) + 61
    );
    await waitForOutput(
      overlay,
      ({ stderr }) => stderr.includes("category=notification event=dismissed id=hotkeys reason=button")
    );
    const foregroundAfterClose = await frontmostApplicationInfo();
    if (foregroundAfterClose.pid !== foregroundBeforeClose.pid) {
      throw new Error(
        `toast close changed foreground app from ${foregroundBeforeClose.name} to ${foregroundAfterClose.name}`
      );
    }

    await overlay.stop();
    stopped = true;
    await sleep(400);
    const closed = await systemScreenCaptureSamples(hiddenCapturePath, points);
    const comparisons = {};
    for (const point of points) {
      const before = visible.samples[point.name];
      const after = closed.samples[point.name];
      const deltas = before.map((value, index) => Math.abs(value - after[index]));
      comparisons[point.name] = { before, after, deltas };
      if (Math.max(...deltas) > 25) {
        throw new Error(
          `${point.name} changed in macOS system capture while closing overlay: ${JSON.stringify(comparisons[point.name])}`
        );
      }
    }

    return {
      bounds,
      comparisons,
      foregroundBeforeClose,
      foregroundAfterClose,
      visibleCapture: visible,
      closedCapture: closed
    };
  } finally {
    if (!stopped) await overlay.stop();
  }
}

async function testDockHostLifecycle() {
  const host = await startDockHost();
  let helperPID;
  try {
    const output = await waitForOutput(
      host,
      ({ stderr }) => stderr.includes("event=helper-launched")
    );
    const match = output.stderr.match(/event=helper-launched pid=(\d+)/);
    if (!match) throw new Error("helper PID was not logged by Dock host");
    helperPID = Number(match[1]);

    const hostInfo = await runningApplicationInfo(host.pid);
    if (!hostInfo.found || hostInfo.activationPolicy !== 0) {
      throw new Error(`expected regular Dock host, got ${JSON.stringify(hostInfo)}`);
    }

    const helperInfo = await runningApplicationInfo(helperPID);
    if (!helperInfo.found || helperInfo.activationPolicy !== 1) {
      throw new Error(`expected accessory browser helper, got ${JSON.stringify(helperInfo)}`);
    }

    const helperWindow = await waitForOverlayWindow(helperPID);
    if (helperWindow.sharingState !== 0) {
      throw new Error(`expected helper sharingState=0, got ${helperWindow.sharingState}`);
    }

    await terminateApplication(host.pid);
    await waitForProcessExit(host.pid);
    await waitForProcessExit(helperPID);
    return { hostPID: host.pid, helperPID, hostInfo, helperInfo, helperWindow };
  } finally {
    await host.stop();
    if (helperPID) {
      try {
        process.kill(helperPID, "SIGTERM");
      } catch {
        // The normal host termination path already stopped the helper.
      }
    }
  }
}

async function testModifierHotKeys(server) {
  const inputStatus = await syntheticInputStatus();
  if (!inputStatus.accessibilityTrusted || !inputStatus.syntheticModifierStateVisible) {
    throw new BlockedError("macOS did not allow synthetic HID modifier-state E2E", inputStatus);
  }

  const foregroundTarget = await frontmostApplicationInfo();
  const overlay = await startOverlay(`${server.origin}/clipboard.html`);
  try {
    let info = await windowInfo(overlay.pid);
    if (!info.found) throw new Error("overlay window not visible before hotkey");
    await postModifierHotKey("left");
    await sleep(500);
    info = await windowInfo(overlay.pid);
    if (info.found) throw new Error("left modifier hotkey did not hide overlay");
    await activateApplication(foregroundTarget.pid);
    await sleep(300);
    const foregroundBeforeShow = await frontmostApplicationInfo();
    if (foregroundBeforeShow.pid !== foregroundTarget.pid) {
      throw new Error(`failed to restore foreground app ${foregroundTarget.name}`);
    }
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      await postModifierHotKey("right");
      await sleep(700);
      info = await windowInfo(overlay.pid);
      if (info.found) break;
      await sleep(300);
    }
    if (!info.found) throw new Error("right modifier hotkey did not show overlay");
    const foregroundAfterShow = await frontmostApplicationInfo();
    if (foregroundAfterShow.pid !== foregroundBeforeShow.pid) {
      throw new Error(
        `hotkey changed foreground app from ${foregroundBeforeShow.name} to ${foregroundAfterShow.name}`
      );
    }
    return {
      pid: overlay.pid,
      finalWindow: info,
      foregroundBeforeShow,
      foregroundAfterShow
    };
  } catch (error) {
    throw new Error(`${error.message}\n${overlay.output().stderr}`);
  } finally {
    await overlay.stop();
  }
}

async function testOverlayPaste(server) {
  const inputStatus = await syntheticInputStatus();
  if (!inputStatus.accessibilityTrusted) {
    throw new BlockedError("macOS Accessibility is not trusted for synthetic mouse/keyboard paste E2E", inputStatus);
  }

  const text = `overlay-e2e-paste-${Date.now()}`;
  const foregroundTarget = await frontmostApplicationInfo();
  const overlay = await startOverlay(`${server.origin}/clipboard.html`);
  try {
    await waitForServerEvent(server, (event) => event.page === "clipboard" && event.type === "ready");
    await activateApplication(foregroundTarget.pid);
    await sleep(300);
    await pasteTextIntoOverlay(overlay.pid, text);
    const event = await waitForServerEvent(
      server,
      (candidate) => candidate.page === "clipboard" && candidate.type === "input" && candidate.text.includes(text),
      5000
    );
    const occurrences = (event.text.match(new RegExp(text, "g")) || []).length;
    if (occurrences !== 1) {
      throw new Error(`expected one pasted text occurrence, got ${occurrences}`);
    }
    const foregroundAfterPaste = await frontmostApplicationInfo();
    if (foregroundAfterPaste.pid !== foregroundTarget.pid) {
      throw new Error(
        `overlay input changed foreground app from ${foregroundTarget.name} to ${foregroundAfterPaste.name}`
      );
    }
    return {
      pastedText: text,
      inputText: event.text,
      foregroundBeforePaste: foregroundTarget,
      foregroundAfterPaste
    };
  } catch (error) {
    throw new Error(`${error.message}\n${overlay.output().stderr}`);
  } finally {
    await overlay.stop();
  }
}

async function testOverlayStoragePersistence(server) {
  const token = `overlay-e2e-storage-${Date.now()}`;
  const writeURL = `${server.origin}/persistence.html?mode=write&token=${encodeURIComponent(token)}`;
  const readURL = `${server.origin}/persistence.html?mode=read&token=${encodeURIComponent(token)}`;

  let overlay = await startOverlay(writeURL);
  try {
    const writeEvent = await waitForServerEvent(
      server,
      (event) => event.page === "persistence" && event.mode === "write" && event.token === token,
      5000
    );
    if (!writeEvent.cookie.includes(token) || writeEvent.localStorageValue !== token) {
      throw new Error("test page did not write cookie and localStorage");
    }
    await sleep(500);
  } finally {
    await overlay.stop();
  }

  overlay = await startOverlay(readURL);
  try {
    const readEvent = await waitForServerEvent(
      server,
      (event) => event.page === "persistence" && event.mode === "read" && event.token === token,
      5000
    );
    if (!readEvent.cookie.includes(token)) {
      throw new Error("cookie did not persist across overlay restart");
    }
    if (readEvent.localStorageValue !== token) {
      throw new Error("localStorage did not persist across overlay restart");
    }
    return { cookiePersisted: true, localStoragePersisted: true };
  } finally {
    await overlay.stop();
  }
}

async function testOverlayPopupNavigation(server) {
  const overlay = await startOverlay(`${server.origin}/popup.html`);
  try {
    await waitForServerEvent(
      server,
      (event) => event.page === "popup" && event.type === "target-loaded",
      5000
    );
    return { openedInCurrentTab: true };
  } finally {
    await overlay.stop();
  }
}

async function importPlaywright() {
  try {
    return await import("playwright");
  } catch (error) {
    throw new BlockedError(
      "Playwright package is not available. Run via: npx --yes --package playwright node tools/e2e/run-e2e.mjs --all",
      { cause: error.message }
    );
  }
}

function chromeExecutablePath(playwright) {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  return playwright.chromium.executablePath();
}

async function launchExtensionContext(playwright, userDataDir, extraArgs = []) {
  const executablePath = chromeExecutablePath(playwright);
  return playwright.chromium.launchPersistentContext(userDataDir, {
    headless: false,
    executablePath,
    args: [
      `--disable-extensions-except=${extensionRoot}`,
      `--load-extension=${extensionRoot}`,
      "--disable-features=DisableLoadExtensionCommandLineSwitch",
      "--no-first-run",
      "--no-default-browser-check",
      ...extraArgs
    ]
  });
}

async function extensionServiceWorker(context) {
  let worker = context.serviceWorkers()[0];
  if (!worker) {
    worker = await context.waitForEvent("serviceworker", { timeout: 10000 });
  }
  if (!worker?.url().startsWith("chrome-extension://")) {
    throw new Error("extension service worker not found");
  }
  return worker;
}

async function setEnabledOrigin(worker, origin, enabled) {
  await worker.evaluate(
    async ({ origin: targetOrigin, enabled: nextEnabled }) => {
      const result = await chrome.storage.local.get({ enabledOrigins: {} });
      const enabledOrigins = result.enabledOrigins || {};
      if (nextEnabled) {
        enabledOrigins[targetOrigin] = true;
      } else {
        delete enabledOrigins[targetOrigin];
      }
      await chrome.storage.local.set({ enabledOrigins });
    },
    { origin, enabled }
  );
}

async function testExtensionFocusPersistence(server, keepChrome) {
  const playwright = await importPlaywright();
  const profileDir = path.join(stateRoot, "chrome-extension-profile");
  await rm(profileDir, { recursive: true, force: true });
  await mkdir(profileDir, { recursive: true });
  const focusURL = `${server.origin}/focus.html`;
  const origin = server.origin;

  let context = await launchExtensionContext(playwright, profileDir);
  try {
    const page = await context.newPage();
    await page.goto(focusURL);
    await page.waitForFunction(() => Boolean(window.__focusSnapshot));
    const worker = await extensionServiceWorker(context);
    const disabledDispatchResult = await page.evaluate(() => window.__dispatchTrackedEvents());
    if (disabledDispatchResult.delta <= 0) {
      throw new Error("focus test page did not receive events before enabling guard");
    }
    await setEnabledOrigin(worker, origin, true);
    await page.reload();
    await page.waitForFunction(() => Boolean(window.__focusSnapshot));
    await page.waitForTimeout(500);
    const dispatchResult = await page.evaluate(() => window.__dispatchTrackedEvents());
    if (dispatchResult.delta !== 0) {
      throw new Error(`focus guard did not block events after enable, delta=${dispatchResult.delta}`);
    }
    const snapshot = await page.evaluate(() => window.__focusSnapshot());
    if (snapshot.hidden !== false || snapshot.visibilityState !== "visible" || snapshot.hasFocus !== true) {
      throw new Error(`focus guard snapshot is not visible/focused: ${JSON.stringify(snapshot)}`);
    }
  } finally {
    await context.close();
  }

  context = await launchExtensionContext(playwright, profileDir);
  try {
    const page = await context.newPage();
    await page.goto(focusURL);
    await page.waitForFunction(() => Boolean(window.__focusSnapshot));
    await extensionServiceWorker(context);
    await page.waitForTimeout(500);
    const dispatchResult = await page.evaluate(() => window.__dispatchTrackedEvents());
    if (dispatchResult.delta !== 0) {
      throw new Error(`enabled origin did not persist across browser restart, delta=${dispatchResult.delta}`);
    }
    const snapshot = await page.evaluate(() => window.__focusSnapshot());
    if (snapshot.hidden !== false || snapshot.visibilityState !== "visible" || snapshot.hasFocus !== true) {
      throw new Error(`persisted focus guard snapshot is not visible/focused: ${JSON.stringify(snapshot)}`);
    }
    const worker = await extensionServiceWorker(context);
    const stored = await worker.evaluate(async () => chrome.storage.local.get({ enabledOrigins: {} }));
    return { origin, storedOrigins: Object.keys(stored.enabledOrigins || {}) };
  } finally {
    if (!keepChrome) {
      await context.close();
    }
  }
}

async function testExtensionReload(keepChrome) {
  const playwright = await importPlaywright();
  const profileDir = path.join(stateRoot, "chrome-extension-reload-profile");
  await rm(profileDir, { recursive: true, force: true });
  await mkdir(profileDir, { recursive: true });
  const context = await launchExtensionContext(playwright, profileDir);
  try {
    const page = await context.newPage();
    await page.goto("about:blank");
    const worker = await extensionServiceWorker(context);
    const extensionId = new URL(worker.url()).host;
    await worker.evaluate(() => chrome.runtime.reload());
    await sleep(1000);
    return { extensionId, mode: "runtime.reload" };
  } finally {
    if (!keepChrome) {
      await context.close();
    }
  }
}

async function testScreenSharePrivacy(server, keepChrome) {
  const playwright = await importPlaywright();
  const profileDir = path.join(stateRoot, "chrome-screen-share-profile");
  await rm(profileDir, { recursive: true, force: true });
  await mkdir(profileDir, { recursive: true });
  const context = await playwright.chromium.launchPersistentContext(profileDir, {
    headless: false,
    executablePath: chromeExecutablePath(playwright),
    args: [
      "--no-first-run",
      "--no-default-browser-check",
      "--use-fake-ui-for-media-stream",
      "--auto-select-desktop-capture-source=Entire screen",
      "--allow-http-screen-capture"
    ]
  });
  let overlay;

  try {
    const page = await context.newPage();
    await page.goto(`${server.origin}/screen-share.html`);
    const capture = await page.evaluate(() => window.__startDisplayCapture());
    if (!capture.ok) {
      throw new BlockedError("display capture was not granted by browser or macOS", capture);
    }

    overlay = await startOverlay(`${server.origin}/overlay-marker.html`);
    const overlayInfo = await windowInfo(overlay.pid);
    if (!overlayInfo.found) throw new Error("overlay marker window not found");
    const bounds = overlayInfo.bounds;
    const screenSize = await page.evaluate(() => ({ width: window.screen.width, height: window.screen.height }));
    const points = {
      browserCenter: {
        x: Number(bounds.X) + Number(bounds.Width) / 2,
        y: Number(bounds.Y) + Number(bounds.Height) / 2,
        screenWidth: screenSize.width,
        screenHeight: screenSize.height
      },
      toastCenter: {
        x: Number(bounds.X) + Number(bounds.Width) - 202,
        y: Number(bounds.Y) + 92,
        screenWidth: screenSize.width,
        screenHeight: screenSize.height
      }
    };
    const visibleSamples = {};
    for (const [name, point] of Object.entries(points)) {
      visibleSamples[name] = await page.evaluate(
        (input) => window.__sampleDisplayCapture(input),
        point
      );
      if (!visibleSamples[name].ok) {
        throw new BlockedError("display capture sampling failed", visibleSamples[name]);
      }
    }

    const [red, green, blue] = visibleSamples.browserCenter.pixel;
    const markerVisible = red > 220 && green < 40 && blue > 220;
    if (markerVisible) {
      throw new Error("overlay marker color was visible in display capture");
    }

    await overlay.stop();
    overlay = undefined;
    await sleep(500);

    const hiddenSamples = {};
    for (const [name, point] of Object.entries(points)) {
      hiddenSamples[name] = await page.evaluate(
        (input) => window.__sampleDisplayCapture(input),
        point
      );
      if (!hiddenSamples[name].ok) {
        throw new BlockedError("display capture sampling failed after overlay closed", hiddenSamples[name]);
      }

      const deltas = visibleSamples[name].pixel.map(
        (value, index) => Math.abs(value - hiddenSamples[name].pixel[index])
      );
      if (Math.max(...deltas) > 25) {
        throw new Error(
          `${name} changed in display capture while closing overlay: ${JSON.stringify({
            visible: visibleSamples[name].pixel,
            hidden: hiddenSamples[name].pixel,
            deltas
          })}`
        );
      }
    }

    return { overlayBounds: bounds, points, visibleSamples, hiddenSamples };
  } finally {
    if (overlay) await overlay.stop();
    if (!keepChrome) {
      await context.close();
    }
  }
}

async function main() {
  const options = parseArgs();
  const usesOverlayApplication = options.app || options.screenShare;
  const reporter = new Reporter();
  await mkdir(stateRoot, { recursive: true });
  const server = await startLocalServer();
  reporter.log(`local server ${server.origin}`);

  try {
    if (usesOverlayApplication) {
      await rm(overlayE2EProfile, { recursive: true, force: true });
    }
    await reporter.step("unit-and-extension-syntax", testUnitAndExtensionSyntax);
    if (options.app) {
      await reporter.step("dock-host-lifecycle", testDockHostLifecycle);
      await reporter.step("overlay-smoke-and-privacy", testOverlaySmoke);
      await reporter.step("system-screen-capture-overlay-exclusion", () => testSystemScreenCapturePrivacy(server));
      await reporter.step("overlay-modifier-hotkeys", () => testModifierHotKeys(server));
      await reporter.step("overlay-native-command-v-paste", () => testOverlayPaste(server));
      await reporter.step("overlay-cookie-and-storage-persistence", () => testOverlayStoragePersistence(server));
      await reporter.step("overlay-popup-navigation", () => testOverlayPopupNavigation(server));
    }
    if (options.extension) {
      await reporter.step("extension-focus-guard-persistence", () => testExtensionFocusPersistence(server, options.keepChrome));
    }
    if (options.reloadExtension) {
      await reporter.step("extension-runtime-reload", () => testExtensionReload(options.keepChrome));
    }
    if (options.screenShare) {
      await reporter.step("screen-share-overlay-exclusion", () => testScreenSharePrivacy(server, options.keepChrome));
    }
  } finally {
    await server.close();
    await rm(overlayE2EApplication, { recursive: true, force: true });
    if (usesOverlayApplication) {
      await rm(overlayE2EProfile, { recursive: true, force: true });
    }
    await reporter.writeReports();
  }

  process.exitCode = reporter.exitCode();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
