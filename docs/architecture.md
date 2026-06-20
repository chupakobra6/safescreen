# Техническая архитектура Overlay Browser

Назначение: фиксировать текущую техническую структуру Overlay Browser, его модули, runtime-поведение
и границы реализованных возможностей.

## Связанные документы

- [../AGENTS.md](../AGENTS.md) - правила работы агентов, область документации и проверки.
- [technical-decisions.md](technical-decisions.md) - устойчивые технические решения и ограничения.
- [runbook.md](runbook.md) - команды запуска, сборки, проверок и ручных сценариев.

## Текущая форма

Overlay Browser - нативное macOS-приложение на SwiftPM, AppKit и WebKit для внутреннего
использования компании. Приложение открывает веб-страницы во встроенном `WKWebView`, хранит
браузерные данные в постоянном WebKit-профиле и предоставляет управляемую оболочку окна поверх
обычных desktop-приложений.

В репозитории также есть companion extension `OverlayFocusGuard` для основного Chrome/Chromium
браузера. Оно не является частью overlay window: расширение нужно для сайтов, которые должны
оставаться в состоянии focused/visible при работе рядом с overlay browser.

Реализовано:

- executable product `OverlayBrowser`;
- встроенный `WKWebView` с адресной строкой, back/forward/reload, дефолтным URL
  `https://chatgpt.com/` и URL из CLI-аргумента;
- постоянный WebKit-профиль через `WKWebsiteDataStore(forIdentifier:)`;
- сохранение cookie, локального хранилища, IndexedDB и кешей между перезапусками приложения;
- `NSPanel` с `.nonactivatingPanel`, `level = .floating`,
  `sharingType = .none`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`;
- непрозрачное читаемое окно по умолчанию с content size `420x820` и стартовой позицией справа как
  узкий sidebar; приложение не задает большой минимальный размер окна, чтобы окно можно было
  свободно ресайзить;
- переключение видимости окна через Carbon hotkeys `Option+Z` и `Option+/`;
- отдельный input mode: окно принимает клавиатурный фокус только при взаимодействии с адресной
  строкой или содержимым страницы;
- фиксированный default cursor внутри WebKit-страниц через `WKUserScript`, чтобы hover над ссылками
  и полями не переключал системный указатель на hand или I-beam;
- silent media policy: запрет autoplay media playback через WebKit-конфигурацию, mute для
  `audio`/`video` и отсутствие native beep при ошибке адреса;
- локальное MV3-расширение `OverlayFocusGuard` с ручным per-origin toggle для основного браузера;
- стартовая HTML-страница как fallback для невалидного явного URL.

Не реализовано:

- слой расширенного DOM-control;
- профильная UI-настройка политик для доменов;
- хранилище пользовательских правил DOM-control;
- сборка `.app`, подпись и дистрибуция вне SwiftPM.
- публикация `OverlayFocusGuard` в Chrome Web Store.

## Модули

| Модуль | Ответственность |
| --- | --- |
| `OverlayBrowser` | AppKit shell: lifecycle, окно, hotkey, адресная строка, навигация `WKWebView`. |
| `OverlayBrowserCore` | Тестируемая логика без AppKit/WebKit shell: стартовая страница, парсинг URL, стартовый destination. |
| `OverlayBrowserWebKit` | Конфигурация WebKit-профиля и фабрика `WKWebViewConfiguration`. |
| `Extensions/OverlayFocusGuard` | Локальное Chrome/Chromium MV3-расширение для per-origin focus/visibility guard в основном браузере. |
| `OverlayBrowserCoreTests` | Тесты URL-нормализации и стартовой страницы. |
| `OverlayBrowserWebKitTests` | Тесты persistent `WKWebsiteDataStore` и стабильного идентификатора профиля. |
| `OverlayFocusGuardExtensionTests` | Тесты manifest и ключевых инвариантов browser extension. |

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

Запуск с URL:

- `URLArgumentParser` берет первый значимый аргумент после имени процесса;
- URL без схемы нормализуется в `https://...`;
- разрешены только `http` и `https`;
- отсутствующий URL открывает `https://chatgpt.com/`;
- невалидный URL открывает встроенную стартовую страницу.

## WebKit-профиль

`BrowserProfile` создает `WKWebViewConfiguration` с одним повторно используемым
`WKWebsiteDataStore` и отдельным `WKUserContentController`.

Текущий идентификатор профиля:

```text
4B801A03-C12C-4C5C-89CE-28D85E385B77
```

Стабильный UUID нужен, чтобы WebKit возвращал один и тот же persistent data store между
перезапусками приложения. Этот store хранит cookie, cache storage, local storage, IndexedDB и другие
поддерживаемые типы website data.

`WKUserContentController` добавляет два user scripts на `documentStart` во все frames:

- cursor policy фиксирует `cursor: default !important` для элементов страницы и псевдоэлементов, а
  также не пишет inline styles в DOM, чтобы не ломать тяжелые React-приложения;
- silent media policy глушит `audio`/`video`, переопределяет playback/resume hooks для media и Web
  дополняет `mediaTypesRequiringUserActionForPlayback = .all`.

Эти политики не отключают текстовый ввод: input mode по-прежнему передает клавиатурные события в
`WKWebView`, но hover не должен менять системный указатель на I-beam или hand, а страницы не должны
издавать звук через обычные `audio`/`video` media пути.

## Окно и input mode

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

Во время input mode окно получает key-фокус, потому macOS иначе не доставит текстовый ввод в
`WKWebView`. При этом включение input mode использует `orderFrontRegardless()` и `makeKey()`, без
активации приложения как обычного foreground-приложения. Выход из input mode очищает first responder
и вызывает `resignKey()`.

Ошибки provisional navigation логируются в stderr и показываются как простая HTML-страница ошибки,
чтобы не оставлять пользователя с пустым окном без причины.

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

По умолчанию расширение ничего не включает для случайных сайтов. `page-guard.js` загружается в MAIN
world без публичного `window.__...` API; focus/visibility patch устанавливается только после
enabled-сигнала для текущего origin. При выключении расширение восстанавливает сохраненные
descriptors и удаляет свои event blockers.

Граница поведения:

- поддерживаются только `http` и `https` origins;
- `chrome://`, `file://`, extension pages и opaque origins не переключаются;
- переключатель хранится по exact origin, например `https://example.com`;
- для сайтов, которые проверяют visibility/focus очень рано при загрузке, после первого включения
  origin стоит перезагрузить вкладку, чтобы guard был применен с `document_start`.

## Технические ограничения

- Базовый runtime - WebKit, не Chromium.
- Минимальная платформа SwiftPM package - macOS 14.
- Основной workflow - Command Line Tools и SwiftPM.
- UI создается кодом AppKit; Xcode project в репозитории отсутствует.
- Документация описывает технические свойства текущего приложения и ближайшие технические точки
  расширения, без исторических продуктовых сценариев.
