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
  Web Audio.
- URL parser принимает только `http` и `https`; URL без схемы получает `https://`.
- Окно приложения реализовано как `NSPanel` с `sharingType = .none`, `.nonactivatingPanel` и
  управляемым input mode.
- Дефолтный content size окна: `1280x800`; минимальный размер: `980x640`; окно полупрозрачное.
- Input mode может делать окно key window для доставки текста в `WKWebView`, но не должен
  активировать приложение как обычное foreground-окно.
- Глобальная горячая клавиша реализована через Carbon hotkey, чтобы не добавлять отдельную
  зависимость только ради переключения видимости.
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
- После изменения window privacy должен проходить runtime readback `CGWindowSharingState == 0` для
  окна процесса `OverlayBrowser`.
- После документационной чистки `rg` по активным Markdown-документам не должен находить старые
  назначения, исторические этапы или устаревшие product names.
