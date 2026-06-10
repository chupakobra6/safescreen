# Architecture

SafeScreen состоит из трех больших частей: capture, compositor и output. Browser companion появляется
только на третьем уровне как диагностический UX-слой.

## High-level flow

```text
Real macOS screen/windows
        |
        v
ScreenCaptureKit capture + content filters
        |
        v
Privacy compositor
        |
        +--> Stage 1 preview window
        |
        +--> Stage 2 SafeScreen virtual display
        |
        +--> Future optional outputs: OBS source, virtual camera, recording
```

## Capture layer

Responsibilities:

- enumerate displays, running apps and windows;
- map user choices to stable window/app identifiers where possible;
- capture frames through ScreenCaptureKit;
- apply `SCContentFilter` to exclude private apps/windows;
- track frame metadata, resolution, color space and timing.

The capture layer must not assume that excluding a window reconstructs whatever was behind it. If a
private window covers allowed content, the compositor must make a product decision: neutral
background, rearranged allowed windows, or user-facing warning.

## Privacy compositor

Responsibilities:

- render only allowed content into the SafeScreen output;
- avoid mirroring real Dock, menu bar, notification banners and desktop files by default;
- provide layout modes:
  - `Clean Desktop`: allowed windows on neutral background, no system chrome;
  - `Natural Desktop`: safe fake menu bar/Dock with only allowed state;
  - `Focus App Layout`: one or several allowed windows arranged for calls;
- render cursor deliberately, without leaking private hover state;
- expose a preview that exactly matches the outgoing output.

Implementation bias:

- Use Metal for frame processing once real code starts.
- Keep CPU fallback only if it is explicitly needed for tests or early prototypes.
- Keep compositor state deterministic enough for screenshot/video regression tests.

## Output layer

### Stage 1: preview window

The simplest output is an ordinary macOS window. It is useful for the MVP because browser calls and
OBS can share a window source. It does not prove the "full monitor" workflow.

### Stage 2: virtual display

The target output is a virtual display named `SafeScreen` that browser call apps can select as an
entire-screen/monitor source.

Expected constraints:

- may require System Extension or DriverKit research;
- must use documented Apple APIs and explicit user approval;
- must have a clear uninstall/rollback path;
- must not require SIP bypass or private API;
- must be validated against actual browser source pickers.

### Future optional outputs

- OBS source: useful for streamers and easier to adopt than a virtual display for some users.
- Virtual camera: useful only when the app wants camera-like output; it is not the primary target
  because screen text may be degraded and UX is less natural for "share screen" workflows.
- Local recording: useful for validation and demos.

## Browser companion

The browser extension is a diagnostic companion, not a stealth layer.

Allowed responsibilities:

- show which browser-observable events occurred on the current page;
- log `visibilitychange`, `focus`, `blur`, fullscreen lifecycle and screen-share lifecycle;
- warn when a site asks for monitor capture or behaves unexpectedly;
- guide the user toward selecting the `SafeScreen` display;
- export a compatibility report.

Explicitly out of scope:

- spoofing or suppressing focus/visibility/fullscreen events;
- hiding the extension from the user;
- bypassing browser proctoring or corporate monitoring;
- injecting into native call clients.

## Audio

Audio is not part of the first MVP. It should be treated as a separate milestone because "hide app
audio from a call" requires different machinery than video compositing.

Possible future modes:

- no system audio: safest default for calls;
- allowlisted app audio: requires virtual audio/mixer work;
- microphone passthrough with noise controls;
- explicit warning when browser or call client captures system audio outside SafeScreen control.

## Threat model boundary

SafeScreen protects the outgoing pixels and, later, controlled audio outputs. It does not protect
against:

- native apps with Screen Recording permission capturing the real display;
- native apps with Accessibility permission inspecting focus/UI state;
- MDM/root/system agents;
- users selecting the wrong source in a browser picker;
- private windows being visible on a real physical screen to people nearby.
