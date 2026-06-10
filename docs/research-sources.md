# Research Sources

Этот файл фиксирует источники, на которых основаны текущие технические допущения. Перед
реализацией Stage 2 нужно обновить ссылки и проверить актуальное состояние macOS, Xcode, браузеров
и signing/entitlement требований.

## Apple

- ScreenCaptureKit overview:
  <https://developer.apple.com/documentation/screencapturekit/>
- `SCContentFilter`:
  <https://developer.apple.com/documentation/screencapturekit/sccontentfilter>
- `SCContentFilter.init(display:excludingApplications:exceptingWindows:)`:
  <https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init%28display%3Aexcludingapplications%3Aexceptingwindows%3A%29>
- `SCStream`:
  <https://developer.apple.com/documentation/screencapturekit/scstream>
- Apple sample "Capturing screen content in macOS":
  <https://developer.apple.com/documentation/ScreenCaptureKit/capturing-screen-content-in-macos>
- DriverKit:
  <https://developer.apple.com/documentation/driverkit>
- Creating a Driver Using the DriverKit SDK:
  <https://developer.apple.com/documentation/driverkit/creating-a-driver-using-the-driverkit-sdk>
- System Extensions:
  <https://developer.apple.com/documentation/systemextensions>
- Core Media I/O camera extension, for possible future virtual-camera output:
  <https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o>

## Web platform

- W3C Screen Capture:
  <https://www.w3.org/TR/screen-capture/>
- MDN Page Visibility API:
  <https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API>
- MDN `visibilitychange`:
  <https://developer.mozilla.org/en-US/docs/Web/API/Document/visibilitychange_event>
- MDN `blur` event:
  <https://developer.mozilla.org/en-US/docs/Web/API/Element/blur_event>

## Current conclusions

- ScreenCaptureKit is the right first capture layer because it is Apple's documented high-performance
  screen/audio capture framework for macOS apps.
- `SCContentFilter` supports excluding apps/windows from a display capture, which matches Stage 1
  and Stage 2 video filtering.
- Web `getDisplayMedia` is user-choice based. A site receives the source the user chooses, so
  SafeScreen must guide the user to select the SafeScreen output rather than trying to intercept a
  native browser picker.
- Browser pages can observe their own lifecycle/focus/visibility events. SafeScreen can keep those
  out of the transmitted pixels, but should not claim to make those browser events impossible.
- Virtual display output is the main Stage 2 R&D risk. Treat it as a first-class milestone with
  signing, entitlement, install, uninstall, latency and browser-picker validation.
