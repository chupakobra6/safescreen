# Чеклист Требований

Проект: safescreen
Обновлено: 2026-06-20

## Значения Статусов
Используй `кандидат`, `принято`, `в работе`, `готово`, `отложено`, `заблокировано` или `отклонено`.

## Требования
| ID | Статус | Источник | Требование | Критерий приемки | Доказательства |
| --- | --- | --- | --- | --- | --- |
| REQ-001 | `готово` | S002 | Ввести единое понятное логирование overlay app и E2E runner. | Логи имеют категории, стабильные префиксы, PID/time context и пишутся в stderr/stdout без разрозненных `fputs`. | `AppLog.swift`; `[OverlayBrowser]`; `[OverlayFocusGuard]`; `[e2e]`; `npm run check` |
| REQ-002 | `готово` | S002 | Добавить CLI E2E runner, который агент может запускать без ручной Xcode GUI работы. | Одна команда запускает build, unit checks, локальные pages, overlay smoke, privacy readback, hotkey probe, paste probe и extension checks; отчет сохраняется в `logs/`. | `tools/e2e/run-e2e.mjs`; `npm run e2e` |
| REQ-003 | `готово` | S002 | Добавить локальные E2E страницы для clipboard/paste, focus/visibility и display capture. | Страницы обслуживаются локальным тестовым сервером и имеют machine-readable status для runner. | `clipboard.html`, `focus.html`, `screen-share.html`, `overlay-marker.html` внутри `tools/e2e/run-e2e.mjs` |
| REQ-004 | `готово` | S002 | Проверять, что overlay window не попадает в системный screen/capture readback. | Автоматический тест проверяет `CGWindowSharingState == 0`; browser `getDisplayMedia` test дает pass или явный blocked/manual-permission status. | `overlay-smoke-and-privacy` pass; `screen-share-overlay-exclusion` blocked без macOS display-capture permission |
| REQ-005 | `готово` | S002 | Проверять OverlayFocusGuard: focus/visibility события, per-origin toggle и persistence. | E2E runner запускает Chromium/Chrome с unpacked extension и persistent profile, включает origin, перезагружает страницу и проверяет сохраненное enabled-состояние. | `npm run e2e:extension` pass |
| REQ-006 | `готово` | S002 | Автоматизировать обновление unpacked browser extension. | Есть команда/скрипт, который запускает тестовый Chrome profile с актуальной папкой extension и может перезагрузить extension без ручного открытия `chrome://extensions`. | `tools/extension/start-dev-chrome.mjs`; `tools/extension/reload-focus-guard.mjs`; `npm run extension:reload` pass |

## Ограничения
| ID | Статус | Источник | Ограничение | Доказательства |
| --- | --- | --- | --- | --- |

## Обязательная Валидация
| ID | Статус | Источник | Валидация | Доказательства |
| --- | --- | --- | --- | --- |
| VAL-001 | `готово` | S002 | `swift test` | `npm run check` |
| VAL-002 | `готово` | S002 | `node --check` для extension scripts и manifest JSON parse | `npm run check` |
| VAL-003 | `готово` | S002 | `node tools/e2e/run-e2e.mjs --all` или documented focused subset | `npm run e2e` |

## Границы Объема
| ID | Статус | Источник | Граница | Примечания |
| --- | --- | --- | --- | --- |
