# Development Process With Codex

Этот файл описывает, как вести разработку SafeScreen со мной так, чтобы проект двигался маленькими
проверяемыми шагами.

## Рабочий цикл

1. Выбираем один milestone из [stages.md](stages.md).
2. Формулируем acceptance criteria для текущего шага.
3. Я читаю ближайший код/документы и даю короткий план с файлами, которые будут затронуты.
4. Делаю изменение маленьким scope.
5. Запускаю самую узкую релевантную проверку.
6. Если изменение внутри git-репозитория, коммичу только свои файлы локально.
7. В финале пишу, что изменилось, чем проверено и какой commit получился.

## Как ставить задачи

Хорошая задача:

```text
Сделай Stage 1 prototype: macOS menu bar app, список окон, preview window без Dock/menu bar.
```

Еще лучше:

```text
Сделай первый вертикальный срез Stage 1:
- SwiftUI menu bar app;
- ScreenCaptureKit capture одного display;
- denylist одного выбранного приложения;
- preview window;
- без virtual display и без audio.
```

Плохая задача для одного шага:

```text
Сделай полностью SafeScreen.
```

Такой запрос надо разбивать, иначе мы смешаем UI, permissions, compositor, virtual display,
browser compatibility и audio.

## Разработка по уровням

### Stage 1

Ожидаемый стиль работы:

- сначала scaffold macOS app;
- затем ScreenCaptureKit capture без фильтров;
- затем фильтрация приложений/окон;
- затем compositor без real Dock/menu bar;
- затем benchmark page/recording;
- затем UX вокруг hotkeys/profile.

Проверки:

- `xcodebuild test`, когда появится Xcode project;
- ручная запись preview window;
- screenshot/video artifacts в ignored директориях;
- список известных limitations в docs.

### Stage 2

Ожидаемый стиль работы:

- отдельный R&D spike по виртуальному дисплею;
- decision record: выбранный output path и почему;
- минимальный virtual display output;
- подключение compositor к virtual display;
- browser picker validation;
- remote recording checks.

Проверки:

- browser benchmark;
- Meet/Zoom web manual matrix;
- performance counters;
- uninstall/reinstall test для system extension, если она появится.

### Stage 3

Ожидаемый стиль работы:

- сначала product UX и диагностика;
- затем browser companion extension как прозрачный inspector;
- затем compatibility database;
- затем onboarding/recovery flows.

Проверки:

- extension logs match browser-observable events;
- user can export a report;
- no spoofing/suppression of page events;
- docs stay clear about guarantees and limits.

## Version control

Проект находится в отдельном git-репозитории:

```bash
cd /Users/igor/projects/safescreen
git status --short
```

Правила:

- один логический шаг - один локальный commit;
- не пушить без явной просьбы;
- не коммитить приватные записи, captures, logs, `.env` и временные артефакты;
- если worktree грязный чужими изменениями, не трогать их и коммитить только свои файлы.

## Документация

Документы должны быть такими же проверяемыми, как код:

- не обещать невозможную защиту;
- отделять визуальные лики от browser-observable events;
- фиксировать non-goals рядом с goals;
- обновлять acceptance criteria при изменении scope;
- переносить редкие длинные процедуры в docs, а короткие стабильные правила - в `AGENTS.md`.
