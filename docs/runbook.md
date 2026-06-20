# Ранбук Overlay Browser

Назначение: хранить команды запуска, сборки, проверки и ручные сценарии для текущего приложения
Overlay Browser.

## Среда

- Рабочая директория: `/Users/igor/projects/safescreen`.
- Кодовый путь: SwiftPM через Command Line Tools, без обязательного Xcode GUI.
- Минимальная платформа пакета: macOS 14.
- Основной executable product: `OverlayBrowser`.

Проверить окружение:

```bash
cd /Users/igor/projects/safescreen
swift --version
xcode-select -p
```

## Запуск

Запустить с URL:

```bash
cd /Users/igor/projects/safescreen
swift run OverlayBrowser -- https://example.com
```

Запустить без URL:

```bash
cd /Users/igor/projects/safescreen
swift run OverlayBrowser
```

Поведение:

- без URL открывается `https://chatgpt.com/`;
- URL без схемы нормализуется в `https://...`;
- невалидный явный URL открывает встроенную стартовую страницу;
- `Left Option+Left Shift` и `Right Option+Right Shift` показывают или прячут окно;
- клик вне окна не скрывает окно автоматически;
- дефолтный размер окна - `420x820`, стартовая позиция - справа как узкий sidebar;
- окно можно свободно ресайзить, без большого app-enforced минимального размера;
- чтение и скролл работают без клавиаточного input mode;
- клик в адресную строку или содержимое `WKWebView` переводит окно в input mode;
- `Command+V` и `Control+V` вставляют содержимое clipboard в focused поле overlay window;
- hover внутри `WKWebView` остается на default cursor, включая ссылки и текстовые поля;
- страницы не должны издавать звук через обычные `audio`/`video` пути;
- `Escape` выводит окно из input mode;
- закрытие окна не завершает процесс.

## Сборка и тесты

Собрать:

```bash
cd /Users/igor/projects/safescreen
swift build
```

Запустить тесты:

```bash
cd /Users/igor/projects/safescreen
swift test
```

Проверить browser extension:

```bash
cd /Users/igor/projects/safescreen
node --check Extensions/OverlayFocusGuard/page-guard.js
node --check Extensions/OverlayFocusGuard/content.js
node --check Extensions/OverlayFocusGuard/popup.js
node --check Extensions/OverlayFocusGuard/background.js
node -e 'JSON.parse(require("fs").readFileSync("Extensions/OverlayFocusGuard/manifest.json", "utf8")); console.log("manifest ok")'
swift test --filter OverlayFocusGuardExtensionTests
```

Проверить стиль diff перед коммитом:

```bash
cd /Users/igor/projects/safescreen
git diff --check
```

Проверить структуру проекта:

```bash
cd /Users/igor/projects/safescreen
find . -maxdepth 3 \( -path ./.git -o -path ./.build -o -name .DS_Store \) -prune -o -type f -print | sort
```

## Smoke-запуск без зависания терминала

Команда собирает и запускает `OverlayBrowser`, ждет несколько секунд, затем останавливает процесс.
Она нужна как быстрый sanity-check старта GUI из агента. Если уже запущен другой `OverlayBrowser`,
readback фильтруется по PID временного процесса.

```bash
cd /Users/igor/projects/safescreen
(
  set -e
  swift build
  logfile=$(mktemp /tmp/overlay-browser-smoke.XXXXXX)
  .build/debug/OverlayBrowser >"$logfile" 2>&1 &
  pid=$!
  cleanup() {
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$logfile"
  }
  trap cleanup EXIT
  sleep 4
  OVERLAY_PID="$pid" swift -e 'import CoreGraphics; import Foundation; let targetPID = Int(ProcessInfo.processInfo.environment["OVERLAY_PID"] ?? "") ?? -1; let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]; let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []; let matches = windows.filter { ($0[kCGWindowOwnerName as String] as? String) == "OverlayBrowser" && ($0[kCGWindowOwnerPID as String] as? Int) == targetPID }; guard let window = matches.first else { print("windowFound=false"); exit(1) }; print("windowFound=true"); print("ownerPID=\(targetPID)"); print("sharingState=\(window[kCGWindowSharingState as String] ?? "missing")"); print("bounds=\(window[kCGWindowBounds as String] ?? "missing")")'
  grep -F "OverlayBrowser navigation started: https://chatgpt.com/" "$logfile" >/dev/null
  cat "$logfile"
)
```

Проверить, что после smoke не остался процесс:

```bash
pgrep -fl OverlayBrowser || true
```

## OverlayFocusGuard в основном браузере

Назначение: локальное Chrome/Chromium MV3-расширение для сайтов, которым нужно оставаться
`focused`/`visible` во время работы рядом с overlay browser.

Установка:

1. Открыть `chrome://extensions`.
2. Включить Developer mode.
3. Нажать Load unpacked.
4. Выбрать папку `/Users/igor/projects/safescreen/Extensions/OverlayFocusGuard`.

Использование:

1. Открыть нужный сайт в основном браузере.
2. Нажать иконку `Overlay Focus Guard`.
3. Нажать `Enable for this site`.
4. Проверить badge `ON` на иконке расширения.
5. Если сайт уже был открыт и проверяет focus/visibility при первом скрипте загрузки, один раз
   перезагрузить вкладку после включения origin.

Выключение:

- нажать иконку расширения на том же origin;
- нажать `Disable for this site`;
- badge `ON` должен исчезнуть.

Границы:

- переключатель применяется только к current `http`/`https` origin;
- случайные сайты не получают enabled-состояние;
- `chrome://`, `file://` и extension pages не поддерживаются;
- расширение не публикуется в Chrome Web Store и устанавливается как локальное unpacked extension.

## Ручная проверка UI

Запуск:

```bash
cd /Users/igor/projects/safescreen
swift run OverlayBrowser -- https://example.com
```

Проверить:

- окно открывается и показывает страницу;
- адресная строка загружает `https://...`;
- back, forward и reload работают;
- `Left Option+Left Shift` и `Right Option+Right Shift` прячут и возвращают окно;
- `Command+V` и `Control+V` вставляют текст или изображение из clipboard в активное поле страницы;
- клик по другому приложению не скрывает окно и не меняет `sharingType = .none`;
- при hover над ссылками и текстовыми полями внутри страницы системный курсор остается стрелкой;
- invalid URL в адресной строке не издает системный beep;
- при ошибке загрузки вместо пустого окна показывается простая HTML-страница ошибки, а причина
  пишется в stderr;
- закрытие окна не завершает процесс, повторный hotkey возвращает окно.

## Проверка window privacy

Системный инвариант privacy-поведения: окно `Overlay Browser` должно иметь
`CGWindowSharingState == 0`. Это проверяет настройку macOS window sharing/capture API, которую
обычно используют звонки и демонстрация экрана. Проект не скрывает процесс или окно от локальных
приложений.

```bash
cd /Users/igor/projects/safescreen
(
  set -e
  swift build
  logfile=$(mktemp /tmp/overlay-browser-privacy.XXXXXX)
  .build/debug/OverlayBrowser https://example.com >"$logfile" 2>&1 &
  pid=$!
  cleanup() {
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$logfile"
  }
  trap cleanup EXIT
  sleep 0.5
  OVERLAY_PID="$pid" swift -e 'import CoreGraphics; import Foundation; let targetPID = Int(ProcessInfo.processInfo.environment["OVERLAY_PID"] ?? "") ?? -1; let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]; let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []; let matches = windows.filter { ($0[kCGWindowOwnerName as String] as? String) == "OverlayBrowser" && ($0[kCGWindowOwnerPID as String] as? Int) == targetPID }; guard let window = matches.first else { print("windowFound=false"); exit(1) }; print("windowFound=true"); print("ownerPID=\(targetPID)"); print("sharingState=\(window[kCGWindowSharingState as String] ?? "missing")")'
)
```

Ожидаемый результат:

```text
windowFound=true
ownerPID=<pid>
sharingState=0
```

## Проверка персистентности профиля

Сценарий:

- запустить `OverlayBrowser` с тестовым сайтом, который устанавливает cookie или localStorage;
- выполнить действие, которое сохраняет состояние в сайте;
- закрыть процесс приложения;
- запустить `OverlayBrowser` повторно с тем же URL;
- проверить, что сайт видит сохраненное состояние без повторной настройки.

Быстрая проверка WebKit API:

```bash
swift -e 'import Foundation; import WebKit; let id = UUID(uuidString: "4B801A03-C12C-4C5C-89CE-28D85E385B77")!; let store = WKWebsiteDataStore(forIdentifier: id); print("persistent=\(store.isPersistent)"); print("identifierMatches=\(store.identifier == id)")'
```

Ожидаемый результат:

```text
persistent=true
identifierMatches=true
```

## Рабочее дерево и коммит

Перед финалом задачи:

```bash
cd /Users/igor/projects/safescreen
git status --short
git diff --check
```

Коммитить только файлы текущей задачи:

```bash
git add -- <paths>
git commit -m "<message>"
```
