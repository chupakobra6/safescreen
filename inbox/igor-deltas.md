# Igor Deltas

Назначение: компактно фиксировать важные входящие требования и решения Игоря по Overlay Browser.

## 2026-06-20

### Логирование, E2E и extension tooling

Исходный ввод:

```text
добавь нормальное и понятное логгирование для всего проекта и сделай полноценные е2е тесты на весь функционал чтобы мы всегда понимали работает или нет программа
...
также должен быть автоматизирован процесс обнолвения браузерного расширения чтобы я не руками обновлял его каждый раз из папки
```

Нормализация:

- Нужны понятные структурированные логи для overlay app, extension и tooling.
- Нужен CLI E2E runner без Xcode GUI.
- E2E должен поднимать локальные страницы для paste, focus/visibility и screen-share.
- E2E должен проверять `CGWindowSharingState == 0`, extension focus guard, per-origin persistence и
  reload extension.
- Extension reload должен быть автоматизирован без ручного `chrome://extensions`.

Статус:

- Выполнено в commit `6e511f2`.
- Основные команды: `npm run check`, `npm run e2e`, `npm run extension:dev-chrome`,
  `npm run extension:reload`.
- Permission-gated проверки hotkey/paste/screen-share дают явный `blocked`, если macOS не выдала
  Accessibility или display-capture permissions.

### Упростить tracking требований

Исходный ввод:

```text
прожект луп не нужен оставь тоьлко часть с igor deltas и inbox для отслеживания требований
```

Нормализация:

- Удалить старую отдельную структуру управления требованиями.
- Оставить только `inbox/README.md` и `inbox/igor-deltas.md` как легкий tracking требований.
- Не вести отдельные карты источников, чеклисты, планы и финальные служебные файлы для этого
  проекта без отдельной просьбы.

Статус:

- Выполнено текущей правкой.

### Command+V regression и очистка Playwright кешей

Исходный ввод:

```text
перестала работать вставка с помощью команд в

почисти локальные кеши плейврайта хромиума и тп

на чем у нас написаны е2е тесты? нормальный ли выбор стека? альтернативы?
```

Нормализация:

- `Command+V` в overlay должен работать внутри browser input mode и не давать двойную вставку.
- `Control+V` не нужен.
- Локальные Playwright/Chromium cache и тестовые browser profiles можно очищать как rebuildable
  artifacts.
- E2E stack должен оставаться понятным и пропорциональным задаче.

Статус:

- Выполнено текущей правкой.
