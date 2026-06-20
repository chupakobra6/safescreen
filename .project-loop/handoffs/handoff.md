# Handoff

Проект: safescreen
Обновлено: 2026-06-20

## Цель
- Добавить понятное логирование, E2E-инфраструктуру, проверки screen-share/focus extension,
  per-origin persistence и автоматизированный reload unpacked extension.

## Текущий Шаг
- active step: `STEP-001`
- status: `готово`

## Завершено
- Overlay app получил структурированное stderr-логирование через `AppLog`.
- `OverlayFocusGuard` получил console-логирование с префиксом `[OverlayFocusGuard]`.
- Добавлен `tools/e2e/run-e2e.mjs` с локальными страницами для clipboard, focus/visibility,
  display capture и overlay marker.
- Добавлены npm-скрипты и devDependency `playwright`.
- Добавлены E2E проверки app smoke/privacy, extension focus guard persistence, extension reload и
  screen-share sample.
- Исправлена timing-гонка extension guard: MAIN-world wrappers ставятся на `document_start`
  инертными и включаются по per-origin state.
- Добавлены `tools/extension/start-dev-chrome.mjs` и `tools/extension/reload-focus-guard.mjs`.
- Вынесена `ModifierHotKeyPolicy` в core и покрыта unit-тестами.

## Измененные Файлы
- `.gitignore`
- `Sources/OverlayBrowser/`
- `Sources/OverlayBrowserCore/ModifierHotKeyPolicy.swift`
- `Extensions/OverlayFocusGuard/`
- `Tests/`
- `tools/e2e/run-e2e.mjs`
- `tools/extension/`
- `docs/`
- `package.json`, `package-lock.json`
- `.project-loop/`, `inbox/README.md`

## Проверка
- `npm run check` pass.
- `npm run e2e:app` pass с `blocked` для synthetic hotkey/paste из-за отсутствия macOS
  Accessibility trust.
- `npm run e2e:extension` pass.
- `npm run e2e:reload-extension` pass.
- `npm run e2e:screen-share` pass с `blocked` для display capture permission.
- `npm run e2e` pass; последний отчет:
  `logs/e2e-2026-06-20T06-57-45-451Z.json`.
- `npm run extension:dev-chrome -- --url about:blank` + `npm run extension:reload` pass.

## Агенты
- Subagents отсутствуют.

## Аудит Промптов
- Создается при изменении prompts.

## Пользовательские Дельты
- Отдельный user-deltas stream создается для существенных свежих корректировок, решений или изменений области.

## Риски И Блокеры
- Полностью автоматическая проверка физических modifier-only hotkeys невозможна через synthetic
  `CGEvent.post`, потому приложение читает реальный HID state через `CGEventSource.keyState`.
  Runner явно помечает этот случай как `blocked`; логика распознавания закрыта unit-тестами.
- Paste E2E требует macOS Accessibility trust для процесса, который отправляет synthetic
  mouse/keyboard events.
- Screen-share pixel sample требует Screen Recording/display-capture permission для тестового
  Chromium.
- Branded Google Chrome 149 игнорирует command-line unpacked extension flags; automation по
  умолчанию использует Playwright Chrome for Testing, `CHROME_PATH` оставлен как override.

## Следующее Действие
- При необходимости выдать Codex/terminal Accessibility и Screen Recording permissions, затем
  повторить `npm run e2e`, чтобы hotkey/paste/screen-share шаги стали полноценными pass.

## Обновленные Источники Правды
- `requirements/source-map.md`
- `requirements/checklist.md`
- `plan/delivery-plan.md`
- `plan/current-step.md`
