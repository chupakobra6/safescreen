# Технические решения Overlay Browser

Назначение: хранить короткий список устойчивых технических решений и ограничений Overlay Browser.

## Текущие решения

- Репозиторий собирается как SwiftPM package `OverlayBrowser`.
- Основной executable product: `OverlayBrowser`.
- Минимальная поддерживаемая платформа: macOS 14.
- UI реализуется на AppKit без Xcode project в репозитории.
- Встроенный браузер работает на `WKWebView`.
- Данные сайтов хранятся в persistent `WKWebsiteDataStore` со стабильным UUID профиля.
- WebKit-конфигурация добавляет global user scripts для fixed cursor и silent media policy во всех
  frames.
- WebKit media playback требует пользовательского действия, а user script глушит `audio`/`video` и
  не патчит `AudioContext`, чтобы не ломать сложные приложения.
- URL parser принимает только `http` и `https`; URL без схемы получает `https://`; запуск без URL
  открывает `https://chatgpt.com/`.
- Окно приложения реализовано как `NSPanel` с `sharingType = .none`, `.nonactivatingPanel` и
  управляемым input mode.
- Дефолтный content size окна: `420x820`; стартовая позиция справа как узкий sidebar; окно
  непрозрачное; большой app-enforced минимальный размер не задается.
- Input mode может делать окно key window для доставки текста в `WKWebView`, но не должен
  активировать приложение как обычное foreground-окно.
- Paste shortcut `Command+V` не перехватывается отдельным handler; вставка идет через native
  WebKit/AppKit responder chain текущего focused поля.
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
- Расширенный DOM-control должен строиться внутри WebKit shell через `WKUserScript`,
  `WKScriptMessageHandler` и доменно-ограниченные policies.
- Проект проверяет системные macOS-инварианты capture/focus для звонков и демонстрации экрана, но
  не скрывает процесс или окно от локальных приложений.
- Chromium/CEF/Electron/Tauri не являются текущим базовым путем; рассматривать их только при
  подтвержденной технической необходимости Chrome runtime.

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
- После изменения WebKit profile тесты должны проверять `WKWebsiteDataStore.isPersistent` и
  стабильный `identifier`, а также наличие fixed cursor и silent media user scripts.
- После изменения `OverlayFocusGuard` должны проходить JS syntax checks, manifest JSON parse и
  `OverlayFocusGuardExtensionTests`.
- После изменения app shell, hotkeys, paste, extension guard, persistence, reload или screen-share
  privacy нужно запускать релевантный режим `tools/e2e/run-e2e.mjs`.
- После изменения window privacy должен проходить runtime readback `CGWindowSharingState == 0` для
  окна процесса `OverlayBrowser`; readback должен фильтровать окно по PID тестового процесса, а не
  только по имени owner.
- После документационной чистки `rg` по активным Markdown-документам не должен находить старые
  назначения, исторические этапы или устаревшие product names.
