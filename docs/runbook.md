# Ранбук Overlay Browser

Назначение: хранить команды запуска, сборки, проверки и ручные сценарии для поддерживаемого macOS-
приложения Overlay Browser и отдельно помеченного Windows-архива.

## Среда

- macOS working directory: `/Users/igor/projects/safescreen`; SwiftPM через Command Line Tools, без
  обязательного Xcode GUI; минимальная платформа macOS 14; executable `OverlayBrowser`.

Проверить окружение:

```bash
cd /Users/igor/projects/safescreen
swift --version
xcode-select -p
```

Установить Node tooling для E2E:

```bash
cd /Users/igor/projects/safescreen
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install
npm run playwright:install
```

`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install` ставит JS-зависимости без тяжелого скачивания
браузера на этапе npm install. `npm run playwright:install` отдельно ставит совместимый Chrome for
Testing для extension/screen-share automation. `CHROME_PATH` можно использовать как override, но
обычный branded Google Chrome может игнорировать unpacked extension flags.

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

### Постоянное приложение в Dock

Собрать текущий код и установить обновляемое приложение по постоянному пути
`~/Applications/Overlay Browser.app`:

```bash
cd /Users/igor/projects/safescreen
npm run macos:install
```

При первом запуске команда также регистрирует приложение в Launch Services, закрепляет его в Dock и
один раз перезапускает Dock. Последующие сборки заменяют bundle по тому же пути, поэтому ярлык не
нужно добавлять заново. Перед заменой команда завершает ранее запущенную app-bundle версию, чтобы
следующий клик в Dock всегда запускал свежий бинарник.

Иконка приложения хранится в `Packaging/macOS/AppIcon.png`; готовый bundle получает нативный
`Packaging/macOS/AppIcon.icns` через installer.

Собрать, установить и сразу запустить свежую версию:

```bash
cd /Users/igor/projects/safescreen
npm run macos:install-and-launch
```

У запущенного процесса Dock показывает стандартный running indicator, если индикаторы включены в
настройках Dock. Клик по значку повторно показывает окно, если оно было скрыто хоткеем или кнопкой
закрытия. `Завершить`/`Quit` в контекстном меню значка или `Command+Q` полностью останавливает
Dock host и browser helper, затем убирает indicator.

Поведение:

- без URL открывается `https://chatgpt.com/`;
- при обычном старте создаются две вкладки: активная `ChatGPT` и `AI Studio` с
  `https://aistudio.google.com/`;
- при каждом запуске внутри правого верхнего угла страницы, ниже toolbar, появляется компактный
  toast с напоминанием о горячих клавишах; он закрывается крестиком или автоматически исчезает;
- вкладки используют один persistent WebKit data store и не пересоздаются при переключении;
- при подтвержденном отсутствии активной сессии внутри страницы появляется auto-dismiss toast с
  просьбой войти;
- URL без схемы нормализуется в `https://...`;
- невалидный явный URL открывает встроенную стартовую страницу;
- `Left Option+Left Shift` и `Right Option+Right Shift` показывают или прячут окно;
- клик вне окна не скрывает окно автоматически;
- дефолтный размер окна - `420x820`, стартовая позиция - справа как узкий sidebar;
- окно можно свободно ресайзить, без большого app-enforced минимального размера;
- чтение и скролл работают без клавиаточного input mode;
- клик в адресную строку или содержимое `WKWebView` переводит окно в input mode;
- `Command+V` маршрутизируется штатным AppKit menu item `Edit/Paste` и вставляет содержимое
  clipboard в текущий responder ровно один раз, включая WebKit password fields;
- `Control+V` намеренно не считается paste shortcut;
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

Собрать переносимый универсальный `.app` и ZIP-архив для Apple Silicon и Intel:

```bash
cd /Users/igor/projects/safescreen
tools/macos/package-portable.sh
```

Скрипт собирает обе архитектуры с минимальной платформой macOS 14, объединяет их в один бинарник,
формирует стандартный app bundle, выполняет ad-hoc подпись и пишет архив в `dist/`. Доверенная
подпись Apple Developer ID и notarization требуют отдельного сертификата и профиля Apple; без них
после скачивания получатель может один раз подтвердить запуск через правый клик -> `Открыть`.

Проверить готовый app bundle:

```bash
app="dist/$(find dist -maxdepth 1 -type d -name 'OverlayBrowser-macOS-universal-*' -exec basename {} \; | sort | tail -1)/Overlay Browser.app"
codesign --verify --deep --strict --verbose=2 "$app"
lipo -archs "$app/Contents/MacOS/OverlayBrowser"
plutil -p "$app/Contents/Info.plist"
```

Проверить browser extension:

```bash
cd /Users/igor/projects/safescreen
node --check Extensions/OverlayFocusGuard/page-guard.js
node --check Extensions/OverlayFocusGuard/content.js
node --check Extensions/OverlayFocusGuard/popup.js
node --check Extensions/OverlayFocusGuard/background.js
node --check tools/extension/start-dev-chrome.mjs
node --check tools/extension/reload-focus-guard.mjs
node -e 'JSON.parse(require("fs").readFileSync("Extensions/OverlayFocusGuard/manifest.json", "utf8")); console.log("manifest ok")'
swift test --filter OverlayFocusGuardExtensionTests
```

## E2E-проверки

Основной E2E-runner поднимает локальный HTTP-сервер с тестовыми страницами, собирает приложение,
запускает overlay в отдельном test bundle/profile, проверяет window privacy, Dock activation
policy, lifecycle пары Dock host/browser helper, embedded toast appearance/auto-dismiss, hotkeys,
native `Command+V` в contenteditable и password fields, сохранение foreground PID,
cookie/localStorage после полного рестарта,
расширение `OverlayFocusGuard`, персистентность per-origin toggle, reload extension и screen-share
sample.
Отчеты пишутся в `logs/e2e-*.json` и `logs/e2e-*.log`.

App E2E использует реальные окна macOS. При обычной разработке нужно запускать только затронутую
область; полный app-прогон оставлен для широких изменений и релизной проверки:

```bash
cd /Users/igor/projects/safescreen
npm run e2e:app:notification # startup toast, внешний вид и фактическое удаление после timeout
npm run e2e:app:paste        # обычное и password field
npm run e2e:app:privacy      # системный capture exclusion
npm run e2e:app:hotkeys      # левая и правая modifier-пара
npm run e2e:app:persistence  # cookie и localStorage после рестарта
npm run e2e:app:navigation   # popup navigation
npm run e2e:app:lifecycle    # Dock host и browser helper
```

Несколько областей можно проверить одним запуском через запятую:

```bash
node tools/e2e/run-e2e.mjs --scenario=notification,paste
```

Только полный набор overlay app:

```bash
npm run e2e:app
```

Адресные команды не повторяют unit-тесты и syntax checks: их отдельно выполняет `npm run check`.
Test bundle собирается один раз и переиспользуется всеми выбранными сценариями текущего запуска.

Расширение в тестовом Chrome profile:

```bash
cd /Users/igor/projects/safescreen
npm run e2e:extension
```

Автоматический reload extension в тестовом Chrome profile:

```bash
cd /Users/igor/projects/safescreen
npm run e2e:reload-extension
```

Проверка screen-share exclusion через локальную страницу `getDisplayMedia`:

```bash
cd /Users/igor/projects/safescreen
npm run e2e:screen-share
```

Полный прогон:

```bash
cd /Users/igor/projects/safescreen
npm run e2e
```

Если macOS или Chrome не выдали разрешение на screen recording/display capture, соответствующий
шаг помечается как `blocked`, а не как успешная проверка. Hotkey/paste E2E требуют Accessibility
trust для процесса, который отправляет синтетические mouse/keyboard events; без этого runner также
пишет `blocked`.

## Логи

Приложение пишет структурированные строки в `stderr`:

```text
[OverlayBrowser] app=OverlayBrowser level=info pid=<pid> category=<category> event=<event> key=value
```

Основные категории: `app`, `window`, `hotkey`, `input`, `navigation`.

Расширение пишет в Chrome DevTools console:

```text
[OverlayFocusGuard] { component: "<component>", event: "<event>", ... }
```

Команды tooling для extension пишут в stdout с префиксом `[OverlayFocusGuardTools]`.

Архивное Windows-приложение писало тот же key-value формат в файл:

```text
%LOCALAPPDATA%\OverlayBrowser\logs\overlay-browser.log
```

## Архив Windows: запуск и проверка

Windows-прототип не поддерживается, не изменяется в обычной разработке и не имеет CI. Следующие
команды сохранены только для ручного исследования архива или отдельно согласованной реактивации.

Проверить среду из PowerShell в корне checkout:

```powershell
dotnet --version
$PSVersionTable.PSVersion
```

SDK выбирается через `Windows/global.json`; требуется .NET 10 SDK. Восстановить locked NuGet graph:

```powershell
dotnet restore Windows/OverlayBrowser.Windows.sln --locked-mode
```

Запустить переносимые unit-тесты:

```powershell
dotnet test Windows/tests/OverlayBrowser.Windows.Tests/OverlayBrowser.Windows.Tests.csproj `
  --configuration Release `
  --no-restore
```

Проверить format/analyzers и собрать весь solution:

```powershell
dotnet format Windows/OverlayBrowser.Windows.sln --verify-no-changes --no-restore
dotnet build Windows/OverlayBrowser.Windows.sln --configuration Release --no-restore
```

Запустить Windows-приложение из исходников с ChatGPT по умолчанию:

```powershell
dotnet run --project Windows/src/OverlayBrowser.Windows/OverlayBrowser.Windows.csproj
```

Запустить с локальным или явным URL:

```powershell
dotnet run --project Windows/src/OverlayBrowser.Windows/OverlayBrowser.Windows.csproj -- `
  http://127.0.0.1:8080/clipboard.html
```

Ожидаемое runtime-поведение:

- client size `420x820`, старт справа, обычный resizable window;
- показ не меняет foreground focus;
- `Left Alt+Left Shift` и `Right Alt+Right Shift` сразу показывают/скрывают окно;
- явный клик внутри разрешает WebView2 input, нативный `Ctrl+V` вставляет содержимое один раз;
- `Escape` возвращает focus предыдущему foreground window;
- close button скрывает окно, tray `Exit` завершает процесс;
- повторный запуск не создает второе окно, а показывает существующее без активации;
- страницы не издают звук, cursor внутри страницы и address field остается arrow;
- startup прекращается с ошибкой, если affinity `0x00000011` не установился и не прочитался обратно.

## Архив Windows: publish и self-test

Собрать self-contained single-file executable:

```powershell
dotnet restore Windows/src/OverlayBrowser.Windows/OverlayBrowser.Windows.csproj `
  --runtime win-x64 `
  --locked-mode `
  --no-dependencies

dotnet publish Windows/src/OverlayBrowser.Windows/OverlayBrowser.Windows.csproj `
  --configuration Release `
  --runtime win-x64 `
  --self-contained true `
  --no-restore `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:DebugType=None `
  -p:DebugSymbols=false `
  --output artifacts/portable

Remove-Item artifacts/portable/*.xml -ErrorAction SilentlyContinue
```

Запустить built-in self-test опубликованного приложения:

```powershell
.\artifacts\portable\OverlayBrowser.Windows.exe --self-test
```

Обязательные проверки:

```text
[PASS] windows-version
[PASS] webview2-runtime
[PASS] url-policy
[PASS] window-capture-exclusion: ... affinity=0x00000011 error=0
Self-test passed.
```

Self-test возвращает exit code `1` при любой ошибке. Он проверяет реальный Win32 top-level HWND и
WebView2 Runtime, но не симулирует конкретную браузерную звонилку.

## Архив Windows: installer

GitHub Actions workflow удален, поэтому автоматические portable/installer artifacts больше не
создаются. Сохраненный installer contract находится в
`Windows/installer/OverlayBrowser.Windows.iss`; его ручная сборка требует Inno Setup 6 и отдельно
загруженного официального WebView2 bootstrapper.

## Архив Windows: ручной screen-share smoke test

После успешного self-test один раз выполнить сценарий из
[../Windows/README.md](../Windows/README.md#обязательный-ручной-screen-share-smoke-test) на целевой
Windows-машине в используемой звонилке Chrome/Edge. Проверять нужно именно `Entire screen`, потому
что share отдельной вкладки по определению не включает native overlay.

Если overlay попал в capture, использовать его в звонке нельзя: зафиксировать версии Windows,
Chrome/Edge и звонилки, приложить `%LOCALAPPDATA%\OverlayBrowser\logs\overlay-browser.log` и передать
агенту.

## Общие проверки репозитория

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
  grep -F "category=navigation event=initial-url url=https://chatgpt.com/" "$logfile" >/dev/null
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
4. Выбрать папку `Extensions/OverlayFocusGuard` из checkout репозитория. На текущем Mac это
   `/Users/igor/projects/safescreen/Extensions/OverlayFocusGuard`; на Windows -
   `<checkout>\Extensions\OverlayFocusGuard`.

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

Автоматическое обновление во время разработки:

```bash
cd /Users/igor/projects/safescreen
node tools/extension/start-dev-chrome.mjs --url https://chatgpt.com
node tools/extension/reload-focus-guard.mjs
```

`start-dev-chrome.mjs` открывает отдельный Chrome for Testing/Chromium profile из
`.state/extension-dev-chrome` с подключенной папкой `Extensions/OverlayFocusGuard` и DevTools
endpoint на `127.0.0.1:9222`.
`reload-focus-guard.mjs` подключается к этому endpoint и вызывает `chrome.runtime.reload()` у
service worker расширения. Обычный пользовательский Chrome profile не меняется.

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
- `Command+V` вставляет текст или изображение из clipboard в активное поле страницы ровно один раз;
- password field получает один `paste`, `beforeinput` и `input` на одну команду;
- клик по другому приложению не скрывает окно и не меняет `sharingType = .none`;
- при hover над ссылками и текстовыми полями внутри страницы системный курсор остается стрелкой;
- invalid URL в адресной строке не издает системный beep;
- при ошибке загрузки вместо пустого окна показывается простая HTML-страница ошибки, а причина
  пишется в stderr;
- компактный hotkey/session toast появляется внутри страницы справа сверху и ниже toolbar, не
  создаёт отдельное окно, не получает key focus и исчезает автоматически; единственный
  `BrowserPanel` сохраняет
  `CGWindowSharingState == 0`;
- у запущенного приложения есть Dock indicator и штатный `Quit`, после завершения indicator
  исчезает;
- закрытие окна не завершает процесс, повторный hotkey возвращает окно.

## Проверка window privacy

Системный инвариант privacy-поведения: окно `Overlay Browser` должно иметь
`CGWindowSharingState == 0`. Это проверяет настройку macOS window sharing/capture API, которую
обычно используют звонки и демонстрация экрана. Проект не скрывает процесс или окно от локальных
приложений.

`npm run e2e:app:privacy` делает реальный снимок экрана через macOS `screencapture` при
открытом overlay с активным встроенным toast и после закрытия overlay. Пиксели в центре браузера и
toast должны совпасть: это защищает от отдельной capture surface уведомления. Проверка углов PNG
toast также требует прозрачный alpha, а список окон не должен содержать отдельное toast-окно.

```bash
cd /Users/igor/projects/safescreen
(
  set -e
  swift build
  logfile=$(mktemp /tmp/overlay-browser-privacy.XXXXXX)
  .build/debug/OverlayBrowser --overlay-helper https://example.com >"$logfile" 2>&1 &
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

Автоматическая проверка реального рестарта:

```bash
cd /Users/igor/projects/safescreen
npm run e2e:app:persistence
```

Шаг `overlay-cookie-and-storage-persistence` использует отдельный test bundle identifier, записывает
persistent cookie и localStorage, завершает процесс и проверяет те же значения после нового запуска.
Профиль пользователя не используется.

Канонический пользовательский профиль app bundle находится в
`~/Library/WebKit/com.igor.safescreen.overlay-browser`. При первом переходе с прямого SwiftPM-запуска
приложение один раз мигрирует `~/Library/WebKit/OverlayBrowser`; существующий destination перед
заменой копируется в
`~/Library/Application Support/OverlayBrowser/ProfileMigrations/ProfileBackups`.

Ручной сценарий:

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
