# Технические решения Overlay Browser

Назначение: хранить короткий список устойчивых технических решений и ограничений Overlay Browser.

## Текущие решения

- macOS target собирается как SwiftPM package `OverlayBrowser`; Windows target живет отдельным
  solution `Windows/OverlayBrowser.Windows.sln`.
- Executable products: macOS `OverlayBrowser` и Windows `OverlayBrowser.Windows`.
- Минимальные платформы: macOS 14 и Windows 10 version 2004 (`10.0.19041`).
- UI реализуется на AppKit и WinForms без обязательных Xcode/Visual Studio GUI workflows.
- Встроенный браузер macOS работает на `WKWebView`; Windows - на WebView2 Evergreen Runtime.
- Данные сайтов хранятся в persistent `WKWebsiteDataStore`; identity профиля состоит из стабильных
  UUID и bundle identifier `com.igor.safescreen.overlay-browser`.
- Legacy-профиль прямого SwiftPM-запуска мигрируется в канонический bundle-профиль один раз, с
  backup существующего destination и маркером завершения до создания первого `WKWebView`.
- macOS shell держит две живые вкладки на общем data store: ChatGPT активна при старте, Google AI
  Studio загружается второй; переключение не пересоздает `WKWebView`.
- Login/OAuth navigation, запрашивающая новое WebKit-окно, открывается в текущей вкладке overlay.
- Session toast показывается только при подтвержденном отсутствии сессии или редиректе на login
  host и не называет причиной конкретную cookie, потому что logout может быть серверным.
- Напоминание о modifier-only hotkeys и session alerts используют собственные неактивирующие
  auto-dismiss toast-панели с `sharingType = .none`, без notification permission и Notification
  Center history.
- WebKit-конфигурация добавляет global user scripts для fixed cursor и silent media policy во всех
  frames.
- WebKit media playback требует пользовательского действия, а user script глушит `audio`/`video` и
  не патчит `AudioContext`, чтобы не ломать сложные приложения.
- URL parser принимает только `http` и `https`; URL без схемы получает `https://`; запуск без URL
  открывает `https://chatgpt.com/`.
- Окно приложения реализовано как `NSPanel` с `sharingType = .none`, `.nonactivatingPanel` и
  управляемым input mode.
- macOS executable имеет два process modes: regular Dock host показывает running indicator и
  стандартный `Quit`, accessory helper владеет `BrowserPanel`, WebKit, hotkeys и toast. Host
  завершает helper и отправляет ему Dock reopen через `DistributedNotificationCenter`.
- Дефолтный content size окна: `420x820`; стартовая позиция справа как узкий sidebar; окно
  непрозрачное; большой app-enforced минимальный размер не задается.
- Input mode может делать окно key window для доставки текста в `WKWebView`, но не должен
  активировать приложение как обычное foreground-окно.
- Paste shortcut `Command+V` перехватывается локальным key monitor только для overlay panel,
  вызывает native AppKit paste action и подавляет исходный key event, чтобы избежать двойной
  вставки; `Control+V` не поддерживается как paste shortcut.
- Клик вне `BrowserPanel` не скрывает окно автоматически.
- Ошибки provisional navigation должны логироваться и отображаться в окне, а не оставлять пустой
  экран.
- Overlay app пишет диагностические события в `stderr` в стабильном key-value формате с префиксом
  `[OverlayBrowser]`.
- Глобальные modifier-only горячие клавиши `Left Option+Left Shift` и `Right Option+Right Shift`
  определяются polling-проверкой текущего HID key state через `CGEventSource.keyState`; левая и
  правая стороны проверяются отдельными Carbon key codes.
- Companion extension `OverlayFocusGuard` реализован как локальное Chrome/Chromium MV3-расширение,
  а не как стороннее расширение из магазина.
- `OverlayFocusGuard` хранит состояние только в `chrome.storage.local.enabledOrigins` и включает
  focus/visibility guard вручную для exact `http`/`https` origin.
- `OverlayFocusGuard` пишет диагностические события в Chrome DevTools console с префиксом
  `[OverlayFocusGuard]`.
- MAIN-world script расширения загружается на `document_start` и сразу ставит инертные wrappers,
  чтобы они были раньше listener-ов страницы; активное focus/visibility поведение включается только
  когда текущий exact origin разрешен.
- Автоматизация разработки расширения идет через отдельный Chrome profile из
  `.state/extension-dev-chrome` и CDP reload, а не через ручное обновление на
  `chrome://extensions`; по умолчанию используется Playwright Chrome for Testing/Chromium, потому
  branded Google Chrome может игнорировать command-line unpacked extension flags.
- E2E-runner живет в `tools/e2e/run-e2e.mjs`, поднимает локальные проверочные страницы и пишет
  отчеты в `logs/e2e-*.json`/`.log`.
- App E2E работает в отдельном bundle/profile namespace и проверяет persistent cookie и localStorage
  через останов и повторный запуск процесса, не используя профиль пользователя.
- Расширенный DOM-control должен строиться внутри WebKit shell через `WKUserScript`,
  `WKScriptMessageHandler` и доменно-ограниченные policies.
- Проект проверяет системные macOS-инварианты capture/focus для звонков и демонстрации экрана, но
  не скрывает процесс или окно от локальных приложений.
- Windows shell использует C#/.NET 10, WinForms и прямые Win32 P/Invoke; Electron/CEF/Tauri не нужны
  для текущего контракта.
- Windows website data хранится в постоянном WebView2 user data folder
  `%LOCALAPPDATA%\OverlayBrowser\WebView2`.
- Windows WebView2 mute применяется двумя уровнями: `CoreWebView2.IsMuted = true` и document-start
  silent media script; `Ctrl+V` остается нативным и не перехватывается shell.
- Windows окно показывается через `SW_SHOWNOACTIVATE`/`SWP_NOACTIVATE`, но не получает постоянный
  `WS_EX_NOACTIVATE`, потому что явный клик должен разрешать обычный текстовый ввод.
- `Escape` возвращает focus HWND, который был foreground до явного клика по overlay.
- Windows capture exclusion использует `WDA_EXCLUDEFROMCAPTURE`; приложение обязано прочитать exact
  affinity `0x00000011` обратно и завершиться fail-closed при любом несоответствии.
- Windows modifier hotkeys используют `WH_KEYBOARD_LL`, различают левую/правую стороны, дают одно
  срабатывание на удержание пары и никогда не подавляют исходные события.
- Windows runtime является single-instance; повторный запуск показывает существующее окно, а tray
  предоставляет явный выход из фонового процесса.
- Переносимая Windows-логика находится в `OverlayBrowser.Windows.Core` с target `net10.0`, чтобы ее
  unit-тесты выполнялись на macOS; WinForms/Win32 target cross-buildится на macOS и выполняется только
  на Windows.
- Windows distribution - self-contained single-file `win-x64` executable, portable ZIP и unsigned
  Inno Setup installer с официальным WebView2 Evergreen bootstrapper.
- Windows self-test проверяет системный affinity contract, но финальная гарантия для конкретной
  браузерной звонилки требует ручной демонстрации `Entire screen` на целевой Windows-машине.

## Документационные правила

- Активные документы описывают текущие технические факты, реализованные компоненты и явно помеченные
  технические планы.
- Старые продуктовые назначения, исторические этапы, сырые промпты и чатовые транскрипты не являются
  источником правды для репозитория.
- Если новое решение заменяет старое, активный документ переписывается под актуальное состояние, а
  не дополняется исторической сноской.
- Команды запуска и проверки живут только в [runbook.md](runbook.md).
- Архитектурные детали живут только в [architecture.md](architecture.md).

## Проверочные инварианты

- После изменения target names или module names должен проходить `swift test`.
- После изменения GUI shell должен проходить smoke-запуск `swift run OverlayBrowser -- https://example.com`.
- После изменения WebKit profile тесты должны проверять `WKWebsiteDataStore.isPersistent`,
  стабильный `identifier`, миграцию legacy data с backup и наличие browser user scripts.
- После изменения `OverlayFocusGuard` должны проходить JS syntax checks, manifest JSON parse и
  `OverlayFocusGuardExtensionTests`.
- После изменения app shell, hotkeys, paste, extension guard, persistence, reload или screen-share
  privacy нужно запускать релевантный режим `tools/e2e/run-e2e.mjs`.
- После изменения window privacy должен проходить runtime readback `CGWindowSharingState == 0` для
  окна процесса `OverlayBrowser`; readback должен фильтровать окно по PID тестового процесса, а не
  только по имени owner.
- После изменения Windows Core должны проходить `dotnet format --verify-no-changes`, unit tests и
  solution build без предупреждений.
- После изменения Windows Win32/WebView2 shell Windows CI должен публиковать executable и завершать
  `OverlayBrowser.Windows.exe --self-test` с exact affinity `0x00000011`.
- После изменения Windows packaging должны синхронно проходить portable ZIP и Inno Setup installer;
  NuGet restore выполняется в locked mode.
- После изменения shared `OverlayFocusGuard` или extension tooling extension E2E должен проходить и
  в Windows workflow.
- После документационной чистки `rg` по активным Markdown-документам не должен находить старые
  назначения, исторические этапы или устаревшие product names.
