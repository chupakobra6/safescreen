# SafeScreen

Статус проекта: продуктовая и техническая проработка.

SafeScreen - macOS-приложение для приватной демонстрации экрана. Оно должно создавать отдельный
"безопасный экран" для созвонов и стримов: зрители видят только разрешенные окна и очищенный
desktop, а приватные приложения, уведомления, Dock-индикаторы и лишние окна не попадают в
передаваемую картинку.

## Что строим

SafeScreen не пытается подменять чужой screen share внутри Zoom, Meet или браузера. Вместо этого он
создает контролируемый output, который пользователь явно выбирает как источник демонстрации.

| Уровень | Цель | Output |
| --- | --- | --- |
| 1. MVP | Доказать, что compositor может собирать чистую картинку без скрытых окон. | Preview window, которое можно вручную зашарить. |
| 2. Browser-call ready | Сделать полноценный сценарий для браузерных звонков: "шарю целый SafeScreen-дисплей". | Виртуальный дисплей, видимый браузером как monitor source. |
| 3. Product features | Добавить профили, диагностику и browser companion для прозрачного контроля утечек. | UX-слой вокруг SafeScreen и открытый privacy/compatibility-инспектор. |

Подробный план уровней: [docs/stages.md](docs/stages.md).

## Что не строим

- Не перехватываем кнопку "Share entire screen" у сторонних приложений.
- Не скрываем процессы из Activity Monitor.
- Не маскируем назначение приложения обманными именами.
- Не используем private API, SIP-bypass, kernel tampering или инъекции в звонарки.
- Не строим фичи для обхода прокторинга или корпоративного мониторинга.

Граница продукта: SafeScreen отвечает за то, какие пиксели и звук попадают в выбранный
пользователем источник трансляции. Он не обещает скрыть реальное состояние Mac от локального агента
с системными разрешениями.

## Источник правды

- Уровни разработки: [docs/stages.md](docs/stages.md)
- Архитектура: [docs/architecture.md](docs/architecture.md)
- Browser benchmark: [docs/browser-benchmark.md](docs/browser-benchmark.md)
- Как разрабатывать проект со мной: [docs/development-process.md](docs/development-process.md)
- Research sources: [docs/research-sources.md](docs/research-sources.md)

## Текущие технические ставки

- Захват экрана: Apple ScreenCaptureKit.
- Фильтрация окон/приложений: `SCContentFilter`.
- Композитинг: Metal-first, чтобы держать latency и CPU под контролем.
- Уровень 1 output: обычное preview window.
- Уровень 2 output: виртуальный дисплей через легальный macOS-путь с System Extension/DriverKit
  R&D или эквивалентный публично допустимый механизм.
- Уровень 3 browser companion: расширение для диагностики того, что видит страница, без spoofing
  focus/visibility/fullscreen сигналов.

## Быстрый старт для агента

```bash
cd /Users/igor/projects/safescreen
find . -maxdepth 2 -type f | sort
```

Пока в проекте нет кода и build-команд. Для проверки документации достаточно убедиться, что все
Markdown-файлы существуют, ссылки внутри репозитория не битые, а публичные утверждения не обещают
невозможные системные гарантии.

## Repository Map

| Path | Purpose |
| --- | --- |
| `README.md` | Короткое описание продукта, границы и карта документации. |
| `AGENTS.md` | Правила для будущих Codex-сессий в этом репозитории. |
| `docs/stages.md` | Три уровня разработки SafeScreen и acceptance criteria. |
| `docs/architecture.md` | Техническая архитектура compositor/output/browser companion. |
| `docs/browser-benchmark.md` | Как использовать браузерный прокторинг/звонок как benchmark без ложных гарантий. |
| `docs/development-process.md` | Как будет идти разработка со мной по шагам. |
| `docs/research-sources.md` | Ссылки на Apple/W3C/MDN и выводы из них. |
