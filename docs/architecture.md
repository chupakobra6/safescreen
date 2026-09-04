# Техническая архитектура Overlay Browser

Назначение: фиксировать текущую техническую структуру Overlay Browser, его модули, runtime-поведение
и границы реализованных возможностей.

## Связанные документы

- [../AGENTS.md](../AGENTS.md) - правила работы агентов, область документации и проверки.
- [technical-decisions.md](technical-decisions.md) - устойчивые технические решения и ограничения.
- [runbook.md](runbook.md) - команды запуска, сборки, проверок и ручных сценариев.

## Текущая форма

Overlay Browser состоит из двух нативных desktop-приложений с одним поведенческим контрактом:

- macOS-приложение на SwiftPM, AppKit и WebKit;
- Windows-приложение на C#/.NET 10, WinForms, WebView2 и Win32.

Оба приложения открывают веб-страницы во встроенном браузере, хранят website data в постоянном
профиле и предоставляют управляемое topmost-окно поверх обычных desktop-приложений. Платформенные
shell не используют общий runtime-код: переносимая логика Windows вынесена в отдельную
`OverlayBrowser.Windows.Core`, а общий продуктовый контракт защищается тестами и документацией.

В репозитории также есть companion extension `OverlayFocusGuard` для основного Chrome/Chromium
браузера. Оно не является частью overlay window: расширение нужно для сайтов, которые должны
оставаться в состоянии focused/visible при работе рядом с overlay browser.

Реализовано:

- executable product `OverlayBrowser`;
- две встроенные вкладки `WKWebView` с общими address/back/forward/reload controls: активная при
  старте ChatGPT и фоновая Google AI Studio;
- компактные toast-уведомления внутри правого верхнего угла страницы, ниже toolbar, сообщают о
  modifier-only hotkeys и необходимости повторного входа, автоматически исчезают и наследуют
  capture exclusion единственного `BrowserPanel`;
- постоянный WebKit-профиль через `WKWebsiteDataStore(forIdentifier:)`;
- сохранение cookie, локального хранилища, IndexedDB и кешей между перезапусками приложения;
- одноразовая миграция legacy-профиля SwiftPM-запуска в канонический bundle-профиль с резервной
  копией ранее созданного destination-профиля;
- session toast, когда ChatGPT API подтверждает отсутствие активной сессии или AI Studio
  перенаправляет вкладку на Google Accounts;
- `NSPanel` с `.nonactivatingPanel`, `level = .floating`,
  `sharingType = .none`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`;
- regular host-процесс для стандартного running indicator и `Quit` в Dock плюс отдельный accessory
  helper-процесс для неактивирующего browser panel, WebKit, hotkeys и встроенного toast;
- непрозрачное читаемое окно по умолчанию с content size `420x820` и стартовой позицией справа как
  узкий sidebar; приложение не задает большой минимальный размер окна, чтобы окно можно было
  свободно ресайзить;
- переключение видимости окна через modifier-only hotkeys `Left Option+Left Shift` и
  `Right Option+Right Shift`;
- отдельный input mode: окно принимает клавиатурный фокус только при взаимодействии с адресной
  строкой или содержимым страницы;
- фиксированный default cursor внутри WebKit-страниц через `WKUserScript`, чтобы hover над ссылками
  и полями не переключал системный указатель на hand или I-beam;
- silent media policy: запрет autoplay media playback через WebKit-конфигурацию, mute для
  `audio`/`video` и отсутствие native beep при ошибке адреса;
- локальное MV3-расширение `OverlayFocusGuard` с ручным per-origin toggle для основного браузера;
- структурированное логирование overlay app, extension и extension tooling;
- E2E-runner с изолированным app/profile, локальными страницами для app, hotkeys, paste,
  cookie/localStorage persistence после рестарта, focus guard, extension reload и screen-share
  privacy sample;
- стартовая HTML-страница как fallback для невалидного явного URL;
- executable product `OverlayBrowser.Windows` в отдельном `Windows/` подпроекте;
- WinForms/WebView2 shell с теми же navigation controls, ChatGPT по умолчанию, постоянным профилем,
  fixed cursor, silent media policy, resizable sidebar `420x820` и нативным `Ctrl+V`;
- показ Windows-окна без активации через `SW_SHOWNOACTIVATE`/`SWP_NOACTIVATE`, input mode по явному
  клику и возврат предыдущего foreground focus по `Escape`;
- capture exclusion Windows через `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` с обязательным
  readback `GetWindowDisplayAffinity == 0x00000011` и fail-closed startup;
- modifier-only Windows hotkeys `Left Alt+Left Shift` и `Right Alt+Right Shift` через
  `WH_KEYBOARD_LL`, без подавления исходных клавиатурных событий;
- Windows single-instance coordination, tray lifecycle, file logging и встроенный `--self-test`;
- Windows CI с unit tests, extension E2E, self-contained `win-x64` executable, portable ZIP и Inno
  Setup installer с WebView2 Evergreen bootstrapper.

Не реализовано:

- слой расширенного DOM-control;
- профильная UI-настройка политик для доменов;
- хранилище пользовательских правил DOM-control;
- доверенная подпись Apple Developer ID и notarization macOS-сборки;
- публикация `OverlayFocusGuard` в Chrome Web Store;
- подпись Windows executable/installer доверенным code-signing сертификатом;
- полностью автоматизированная проверка пикселей реальной демонстрации экрана Windows в конкретной
  браузерной звонилке: Windows self-test проверяет системный affinity contract, а финальный capture
  path пока требует один ручной smoke test на целевой машине.

## Модули

| Модуль | Ответственность |
| --- | --- |
| `OverlayBrowser` | AppKit shell с двумя process modes: regular Dock host и accessory browser helper с toast, hotkey, вкладками и `WKWebView`. |
| `OverlayBrowserCore` | Тестируемая логика без AppKit/WebKit shell: URL, вкладки и классификация session state. |
| `OverlayBrowserWebKit` | Конфигурация WebKit-профиля, миграция legacy-данных и фабрика `WKWebViewConfiguration`. |
| `Windows/src/OverlayBrowser.Windows.Core` | Переносимая логика Windows: URL, start destination, hotkey state machine и browser scripts. |
| `Windows/src/OverlayBrowser.Windows` | WinForms/WebView2 shell, Win32 privacy/focus/hotkey, lifecycle, logging и self-test. |
| `Windows/tests/OverlayBrowser.Windows.Tests` | Unit-тесты Windows Core, запускаемые и на macOS, и на Windows. |
| `Windows/installer` | Inno Setup contract для per-user installer и WebView2 bootstrapper. |
| `Packaging/macOS` | Метаданные app bundle и инструкция получателю переносимого macOS-архива. |
| `Extensions/OverlayFocusGuard` | Локальное Chrome/Chromium MV3-расширение для per-origin focus/visibility guard в основном браузере. |
| `tools/e2e` | Node E2E-runner: локальные HTML-страницы, запуск overlay, Chrome/Playwright проверки и отчеты в `logs/`. |
| `tools/extension` | CLI-инструменты для запуска dev Chrome profile и reload локального unpacked extension без `chrome://extensions`. |
| `OverlayBrowserCoreTests` | Тесты URL-нормализации и стартовой страницы. |
| `OverlayBrowserWebKitTests` | Тесты persistent data store, стабильного UUID и безопасной миграции профиля. |
| `OverlayFocusGuardExtensionTests` | Тесты manifest и ключевых инвариантов browser extension. |
| `.github/workflows/windows.yml` | Windows build/test/package pipeline и готовые CI artifacts. |

`tools/macos/package-portable.sh` собирает release-бинарники `arm64` и `x86_64` с минимальной
платформой macOS 14, объединяет их в универсальный `Overlay Browser.app`, выполняет ad-hoc подпись
и упаковывает переносимый ZIP. Такая сборка самодостаточна относительно Swift toolchain, но без
Apple Developer ID и notarization получатель может увидеть одноразовое предупреждение Gatekeeper.

## Runtime-поток

```text
CommandLine.arguments
        |
        v
URLArgumentParser.destination(from:)
        |
        v
OverlayBrowserAppDelegate
        |
        v
BrowserPanel + BrowserViewController
        |
        v
WKWebViewConfiguration from BrowserProfile
        |
        v
WKWebView
```

Windows runtime-поток:

```text
command-line arguments
        |
        v
AppOptions + UrlPolicy
        |
        v
BrowserForm
        |
        +--> WindowPrivacy + HotKeyController + SingleInstanceCoordinator
        |
        v
CoreWebView2Environment with persistent user data folder
        |
        v
WebView2
```

Запуск с URL:

- macOS `URLArgumentParser` и Windows `UrlPolicy` берут первый значимый URL-аргумент;
- URL без схемы нормализуется в `https://...`;
- разрешены только `http` и `https`;
- отсутствующий URL открывает `https://chatgpt.com/`;
- невалидный URL открывает встроенную стартовую страницу.

## Браузерные профили

### macOS WebKit

`BrowserProfile` создает конфигурации обеих вкладок с одним повторно используемым
`WKWebsiteDataStore` и отдельным `WKUserContentController` для каждого `WKWebView`.

Текущий идентификатор профиля:

```text
4B801A03-C12C-4C5C-89CE-28D85E385B77
```

Стабильный UUID и стабильный bundle identifier `com.igor.safescreen.overlay-browser` вместе
определяют persistent data store. WebKit дополнительно разделяет данные по identity приложения,
поэтому прямой SwiftPM executable исторически писал в `~/Library/WebKit/OverlayBrowser`, а app
bundle пишет в `~/Library/WebKit/com.igor.safescreen.overlay-browser`.

Перед первым созданием `WKWebsiteDataStore` канонический app bundle один раз копирует legacy-профиль
в bundle-профиль. Если destination уже существует, его резервная копия сохраняется в
`~/Library/Application Support/OverlayBrowser/ProfileMigrations/ProfileBackups`. Маркер миграции не
позволяет повторному запуску перезаписать более новые cookie. Не-канонические test/SwiftPM bundle
identity миграцию не выполняют.

Store хранит cookie, cache storage, local storage, IndexedDB и другие поддерживаемые типы website
data. Обновление executable или app bundle не удаляет эти каталоги.

`BrowserViewController` держит одновременно два `WKWebView`: ChatGPT активен при старте, AI Studio
загружается во второй вкладке. Переключение не пересоздает web view, поэтому состояние страницы
сохраняется. Login/OAuth navigation с `targetFrame == nil` открывается в текущем web view, а не
теряется как неподдержанное popup-окно. После навигации ChatGPT сначала проверяет наличие видимых
login controls, затем same-origin `/api/auth/session`; AI Studio считается требующим входа на
`/welcome` и при редиректе на `accounts.google.com`. Session toast сообщает только об отсутствии
активной сессии: клиент не может надежно отличить локальное истечение cookie от серверного logout.
Повторные одинаковые уведомления подавляются до подтвержденной авторизации в соответствующей
вкладке.

`WKUserContentController` добавляет два user scripts на `documentStart` во все frames:

- cursor policy фиксирует `cursor: default !important` для элементов страницы и псевдоэлементов, а
  также не пишет inline styles в DOM, чтобы не ломать тяжелые React-приложения;
- silent media policy глушит `audio`/`video`, переопределяет playback/resume hooks для media и Web
  дополняет `mediaTypesRequiringUserActionForPlayback = .all`.

Эти политики не отключают текстовый ввод: input mode по-прежнему передает клавиатурные события в
`WKWebView`, но hover не должен менять системный указатель на I-beam или hand, а страницы не должны
издавать звук через обычные `audio`/`video` media пути.

### Windows WebView2

`BrowserForm` создает `CoreWebView2Environment` с user data folder
`%LOCALAPPDATA%\OverlayBrowser\WebView2`. Папка постоянная и хранит cookie, login, local storage,
IndexedDB, permissions и другие данные WebView2 между перезапусками.

До первой навигации shell ожидает установку трех scripts через
`AddScriptToExecuteOnDocumentCreatedAsync`; WebView2 применяет их к будущим top-level и child-frame
navigations:

- fixed cursor policy совпадает с базовым CSS-контрактом macOS;
- silent media policy глушит `audio`/`video`;
- escape bridge передает `Escape` в host через `chrome.webview.postMessage`.

Кроме script policy, `CoreWebView2.IsMuted = true` выключает весь audio output WebView2, а environment
получает Chromium argument `--autoplay-policy=user-gesture-required`. Обычный Windows `Ctrl+V` не
перехватывается host-кодом и передается focused WebView2 element нативно.

## Окно и input mode

### macOS

`BrowserPanel` создается как floating `NSPanel`. По умолчанию он не становится key window. Это
оставляет чтение и скролл отделенными от клавиаточного ввода.

Окно выставляет `sharingType = .none`. Этот инвариант предназначен для macOS window sharing,
screen capture и приложений, которые используют системные capture API, например звонков и
демонстрации экрана. Проект не скрывает процесс или окно от локальных приложений.

`BrowserViewController` переводит окно в input mode при явном намерении ввода:

- клик или фокус адресной строки;
- mouse/key interaction внутри `FocusAwareWebView`;
- вызов загрузки из адресной строки.

`Escape` выводит окно из input mode. Закрытие окна не завершает процесс; повторный hotkey возвращает
панель. Клик вне окна не скрывает панель автоматически.

При обычном запуске executable работает как regular Dock host и запускает тот же executable с
`--overlay-helper` как accessory child process. Host не создает браузерных окон: он обеспечивает
running indicator, `Command+Q`, Dock `Quit` и пересылает Dock reopen helper-процессу через
`DistributedNotificationCenter`. Helper владеет `BrowserPanel`, WebKit-профилем, hotkeys и
встроенным в browser panel toast. Отдельное окно для уведомлений не создается, поэтому toast не
образует самостоятельную capture surface и скрывается вместе с `BrowserPanel`. Завершение host
останавливает helper; такая граница сохраняет стандартный Dock lifecycle, не
переводя browser panel в regular foreground application.

Во время input mode accessory helper получает key-фокус, потому macOS иначе не доставит текстовый
ввод в `WKWebView`. При этом включение input mode использует `orderFrontRegardless()` и `makeKey()`,
не заменяя foreground-приложение. Выход из input mode очищает first responder и вызывает
`resignKey()`.

Accessory helper создаёт стандартное AppKit-меню `Edit/Paste` с key equivalent `Command+V`.
Menu item вызывает native paste action для текущего responder, включая WebKit password fields.
Local key monitor обрабатывает только `Escape`, поэтому исходный WebKit shortcut и дополнительный
ручной paste-handler больше не могут вставить одно содержимое параллельно. `Control+V` не считается
paste shortcut.

Ошибки provisional navigation логируются в stderr и показываются как простая HTML-страница ошибки,
чтобы не оставлять пользователя с пустым окном без причины.

### Windows

`BrowserForm` - resizable topmost WinForms window без taskbar button. `ShowWithoutActivation`,
`ShowWindow(SW_SHOWNOACTIVATE)` и `SetWindowPos(..., SWP_NOACTIVATE)` используются при первом показе,
hotkey и повторном запуске приложения. Постоянный `WS_EX_NOACTIVATE` не используется: Windows не
сможет доставлять обычный текстовый ввод в WebView2, если top-level window никогда не активируется.

Перед `WM_MOUSEACTIVATE` shell запоминает текущий foreground HWND. Явный клик пользователя активирует
overlay и разрешает ввод; `Escape` очищает input mode и вызывает `SetForegroundWindow` для
запомненного HWND. Показ без клика не меняет foreground focus. Hotkey напрямую проверяет `Visible` и
скрывает окно с первого срабатывания даже во время input mode.

Capture privacy применяется только к собственному top-level HWND. `WindowPrivacy` проверяет Windows
10 build `19041+`, DWM composition, успешный `SetWindowDisplayAffinity` и exact readback
`0x00000011`. Любая ошибка приводит к fail-closed dialog и завершению вместо запуска незащищенного
overlay.

Глобальный low-level keyboard hook отслеживает левую и правую стороны отдельно, защелкивает одно
срабатывание до отпускания пары и всегда вызывает `CallNextHookEx`. Он не скрывает ввод от Windows,
звонков, игр или других процессов.

## Логирование и E2E

Overlay app пишет стабильный key-value формат в `stderr` с префиксом `[OverlayBrowser]`.
Логируемые категории: `app`, `window`, `hotkey`, `input`, `navigation`, `notification`, `profile`,
`session`.

`OverlayFocusGuard` пишет диагностические записи в Chrome DevTools console с префиксом
`[OverlayFocusGuard]` и полями `component`/`event`. CLI-инструменты для расширения используют
префикс `[OverlayFocusGuardTools]`.

`tools/e2e/run-e2e.mjs` поднимает локальный HTTP-сервер и предоставляет страницы:

- `clipboard.html` - contenteditable target для проверки native `Command+V`;
- `password.html` - полноразмерное password field с подсчётом `keydown`, `paste`, `beforeinput` и
  `input`, чтобы одна команда не вставляла пароль дважды;
- `persistence.html` - запись и чтение persistent cookie/localStorage между двумя процессами app;
- `popup.html`/`popup-target.html` - проверка открытия new-window navigation в текущей вкладке;
- `focus.html` - страница с `blur`/`visibilitychange`/`pagehide`/`freeze` событиями для проверки
  `OverlayFocusGuard`;
- `screen-share.html` - страница с `getDisplayMedia` и canvas sample для проверки, что overlay
  marker не попадает в screen-share capture;
- `overlay-marker.html` - яркий overlay marker для privacy sample.

Для app-сценариев runner собирает временный bundle
`com.igor.safescreen.overlay-browser.e2e`, использует отдельный WebKit-профиль и удаляет его после
прогона. Сценарии разделены на `lifecycle`, `notification`, `privacy`, `hotkeys`, `paste`,
`persistence` и `navigation`; выбранные сценарии переиспользуют одну подготовленную test-сборку.
Notification-сценарий ждёт не только timeout, но и фактическое удаление toast view. Реальный
пользовательский профиль E2E не читает и не очищает. Runner пишет
machine-readable отчет в `logs/e2e-*.json` и текстовый лог в `logs/e2e-*.log`. Шаги,
заблокированные системными разрешениями macOS/Chrome, помечаются как `blocked`.

Windows Core unit tests запускаются на любой платформе с .NET 10. На Windows опубликованный executable
дополнительно запускается с `--self-test`: проверяются версия OS, наличие WebView2 Runtime, URL policy
и реальный top-level HWND affinity readback. GitHub Actions выполняет эти проверки, extension E2E и
собирает portable/installer artifacts. Self-test не подменяет ручную проверку browser screen share,
потому что конкретная звонилка может выбирать собственный capture path.

## DOM-Control Слой

Планируемая зона развития - расширенный контроль DOM внутри самого Overlay Browser. Техническая
граница этого слоя:

- инъекция `WKUserScript` на `documentStart` и, при необходимости, после navigation commit;
- отдельные policy objects для доменов или URL-patterns;
- связь страницы с native shell через `WKScriptMessageHandler`;
- явная модель включенных правил, без глобального неявного изменения всех страниц;
- тестовая HTML-страница для проверки injected state, DOM mutations, event hooks и message bridge;
- отсутствие сетевых запросов из control layer без отдельной явной настройки.

Пока этот слой не реализован, документы и код не должны утверждать наличие DOM-control поведения.
Cursor и silent media scripts считаются базовыми WebKit-политиками оболочки, а не расширенным
DOM-control: они не вводят доменные правила, message bridge или пользовательское хранилище правил.

## OverlayFocusGuard Extension

`Extensions/OverlayFocusGuard` - локальное unpacked MV3-расширение для основного браузера. Оно
предназначено для ручного включения на конкретном `http`/`https` origin через popup расширения.

Состав:

- `manifest.json` - MV3 manifest, popup, service worker и два content scripts;
- `page-guard.js` - MAIN-world script на `document_start`, который может подменять
  `document.hidden`, `document.visibilityState`, `document.hasFocus()` и блокировать blur/hidden
  events;
- `content.js` - isolated content script, который читает `chrome.storage.local.enabledOrigins` и
  передает toggle в MAIN-world script;
- `popup.html`, `popup.css`, `popup.js` - один ручной переключатель для текущего origin;
- `background.js` - service worker, который показывает badge `ON` на иконке для включенного origin.

Во время разработки `tools/extension/start-dev-chrome.mjs` запускает отдельный Chrome profile с
подключенным unpacked extension, а `tools/extension/reload-focus-guard.mjs` обновляет расширение
через `chrome.runtime.reload()` по Chrome DevTools Protocol.

По умолчанию расширение не включает enabled-состояние для случайных сайтов. `page-guard.js`
загружается в MAIN world без публичного `window.__...` API и ставит инертные wrappers на
`document_start`, чтобы порядок event listeners был раньше listener-ов страницы. Пока origin
выключен, wrappers возвращают native focus/visibility значения и не блокируют events. После
enabled-сигнала для текущего origin они начинают возвращать visible/focused state и блокировать
blur/hidden events; при выключении остаются инертными для текущего документа.

Граница поведения:

- поддерживаются только `http` и `https` origins;
- `chrome://`, `file://`, extension pages и opaque origins не переключаются;
- переключатель хранится по exact origin, например `https://example.com`;
- для сайтов, которые проверяют visibility/focus очень рано при загрузке, после первого включения
  origin стоит перезагрузить вкладку, чтобы guard был применен с `document_start`.

## Технические ограничения

- Базовый runtime macOS - WebKit; базовый runtime Windows - WebView2 Evergreen.
- Минимальная платформа SwiftPM package - macOS 14; Windows target - Windows 10 version 2004
  (`10.0.19041`) или новее.
- Основной workflow macOS - Command Line Tools и SwiftPM; Windows - .NET CLI и PowerShell.
- UI создается кодом AppKit/WinForms; Xcode и Visual Studio projects для GUI workflow не требуются.
- Windows code можно cross-build/publish на macOS, но Win32 focus/capture contract проверяется только
  Windows self-test и ручным screen-share smoke test.
- Документация описывает технические свойства текущего приложения и ближайшие технические точки
  расширения, без исторических продуктовых сценариев.
