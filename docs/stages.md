# SafeScreen Development Stages

Эта дорожная карта фиксирует три уровня разработки. Уровни идут последовательно: каждый следующий
уровень использует проверенные решения предыдущего, а не заменяет их новым направлением.

## Уровень 1: MVP compositor

Цель: доказать, что SafeScreen может собрать чистую картинку из реального экрана и выбранных окон.

### Пользовательский сценарий

1. Пользователь запускает menu bar app.
2. Приложение запрашивает Screen Recording permission.
3. Пользователь выбирает приложения или конкретные окна, которые нужно скрыть.
4. SafeScreen показывает preview window с тем, что увидит зритель.
5. Пользователь вручную шарит это preview window в Zoom/Meet/OBS/браузере.

### Scope

- Список доступных дисплеев, приложений и окон.
- Hide active window/app hotkey.
- Allowlist/denylist приватных окон.
- Preview window с live-картинкой.
- Базовый privacy compositor:
  - исключает выбранные окна/приложения через ScreenCaptureKit filter;
  - не показывает реальный Dock и menu bar в безопасном output;
  - рисует нейтральный background, если скрытое окно оставляет визуальную пустоту;
  - показывает курсор только в безопасной форме.
- Локальный self-test page для записи/просмотра результата через браузерный `getDisplayMedia`.

### Non-goals

- Виртуальный дисплей.
- System audio filtering.
- Browser extension.
- Попытка скрыть реальное состояние Mac от локального софта.

### Acceptance criteria

- На записи preview window нет скрытого приложения, его уведомлений, Dock-индикаторов и menu bar
  признаков.
- Можно скрыть одно окно браузера, оставив другое окно браузера видимым.
- Переключение фокуса на приватное приложение не меняет безопасную картинку так, чтобы зритель
  увидел приватное приложение.
- Preview стабильно держит целевой режим минимум 1080p/30 FPS на тестовой машине.
- Latency, CPU/GPU load и dropped frames измерены и записаны в `docs/` или validation artifact.

## Уровень 2: Browser-call ready SafeScreen Display

Цель: сделать сценарий, где браузерная звонарка видит SafeScreen как полноценный monitor source.

### Пользовательский сценарий

1. Пользователь запускает SafeScreen.
2. SafeScreen создает виртуальный дисплей `SafeScreen`.
3. Пользователь открывает браузерный звонок.
4. В browser screen picker пользователь выбирает "Entire screen" и дисплей `SafeScreen`.
5. Зрители видят полный безопасный desktop, собранный SafeScreen.

### Scope

- Виртуальный дисплей или другой публично допустимый output, который браузеры видят как monitor
  source.
- Полноэкранный compositor pipeline:
  - разрешенные окна;
  - безопасный background;
  - опциональный fake Dock/menu bar только с разрешенными элементами;
  - управляемый cursor rendering;
  - layout modes: Clean Desktop, Natural Desktop, Focus App Layout.
- Source picker checklist: приложение явно показывает пользователю, какой source нужно выбрать.
- Browser-call validation matrix:
  - Google Meet in Chrome;
  - Google Meet in Safari, если поддержка source picker позволяет;
  - Zoom web client;
  - Discord/Slack web, если нужны как target.
- Browser-only benchmark page, которая записывает полученный поток и сравнивает его с ожидаемым
  clean output.

### Non-goals

- Обман нативных клиентов, которые получили собственные Screen Recording/Accessibility permissions.
- Подмена встроенного дисплея MacBook.
- Скрытие процессов из Activity Monitor.
- Browser event spoofing.

### Acceptance criteria

- Browser-call участник видит `SafeScreen` как целый экран, а не как окно приложения.
- На удаленной записи нет приватных окон, реального Dock, реального menu bar, уведомлений и
  приватных desktop files.
- Если пользователь двигает приватное окно на реальном экране, оно не появляется в SafeScreen.
- Если пользователь двигает разрешенное окно, SafeScreen обновляет его положение без заметных
  артефактов.
- Browser benchmark фиксирует:
  - выбранный display surface;
  - разрешение/FPS;
  - факт отсутствия приватных пикселей в captured stream;
  - события visibility/focus/fullscreen как наблюдаемую браузером область, а не как гарантию
    скрытия.

## Уровень 3: Product features and browser companion

Цель: превратить рабочий SafeScreen Display в удобный продукт с профилями, диагностикой и
расширением, которое прозрачно показывает пользователю, что может наблюдать браузерная страница.

### Scope

- Privacy profiles:
  - Work call;
  - Streaming;
  - Demo;
  - Browser-only safe mode.
- Presets для разрешенных приложений и окон.
- One-click preflight перед звонком:
  - выбран правильный SafeScreen output;
  - приватные приложения скрыты;
  - уведомления подавлены через нормальные macOS-настройки/Focus;
  - на SafeScreen нет реального Dock/menu bar.
- Browser companion extension:
  - открытый inspection panel с тем, какие сигналы страница может видеть;
  - лог `visibilitychange`, `focus`, `blur`, fullscreen changes и screen-share lifecycle;
  - предупреждения, когда сайт ведет себя как агрессивный наблюдатель;
  - подсказки, как оставаться в корректном SafeScreen workflow;
  - экспорт диагностического отчета для воспроизведения багов.
- Compatibility database для браузеров и популярных web-call apps.
- Product onboarding и recovery flows.

### Non-goals

- Подавление или подмена browser focus/visibility/fullscreen событий.
- Прокторинг bypass.
- Маскировка процесса или имени приложения ради сокрытия назначения.
- Activity Monitor handling.

### Acceptance criteria

- Пользователь до звонка видит, что именно будет зашарено и какие лики заблокированы.
- Browser companion показывает наблюдаемые сайтом события в понятном виде.
- Extension помогает диагностировать несовместимость, но не создает ложное чувство полной
  невидимости.
- SafeScreen имеет воспроизводимый demo mode для продаж/тестирования без приватных данных.

## Общий принцип уровней

SafeScreen должен быть честным privacy tool:

- показывать пользователю preview "what others see";
- явно объяснять, какой source нужно выбрать;
- валидировать output через запись, а не через предположение;
- не обещать защиту от локального софта, которому пользователь дал системные разрешения;
- не строить доверие на скрытии процесса, подмене сигналов или private API.
