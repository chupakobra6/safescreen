# Ранбук SafeScreen

Назначение: хранить команды запуска, сборки, проверки и ручные сценарии для текущего прототипа
SafeScreen.

## Среда

- Рабочая директория: `/Users/igor/projects/safescreen`.
- Текущий кодовый путь: SwiftPM через Command Line Tools, без обязательного Xcode GUI.
- Минимальная платформа пакета: macOS 14.
- Основной executable product: `SafeScreenStage0`.

Проверить окружение:

```bash
cd /Users/igor/projects/safescreen
swift --version
xcode-select -p
```

## Запуск Stage 0

Запустить с URL:

```bash
cd /Users/igor/projects/safescreen
swift run SafeScreenStage0 -- https://example.com
```

Запустить без URL:

```bash
cd /Users/igor/projects/safescreen
swift run SafeScreenStage0
```

Поведение:

- без URL открывается встроенная стартовая страница;
- URL без схемы нормализуется в `https://...`;
- `Option+Shift+S` показывает или прячет окно;
- окно Stage 0 не должно появляться в Dock;
- чтение и скролл рассчитаны на passive mode без захвата фокуса, ввод текста может перевести окно в
  input mode.

## Сборка и тесты

Собрать:

```bash
cd /Users/igor/projects/safescreen
swift build
```

Запустить тесты:

```bash
cd /Users/igor/projects/safescreen
swift test
```

Проверить стиль diff перед коммитом:

```bash
cd /Users/igor/projects/safescreen
git diff --check
```

Проверить структуру проекта:

```bash
cd /Users/igor/projects/safescreen
find . -maxdepth 3 -type f | sort
```

## Smoke-запуск без зависания терминала

Команда собирает и запускает `SafeScreenStage0`, ждет несколько секунд, затем останавливает процесс.
Она нужна только как быстрый sanity-check старта GUI из агента.

```bash
cd /Users/igor/projects/safescreen
logfile=$(mktemp /tmp/safescreen-stage0-smoke.XXXXXX)
swift run SafeScreenStage0 -- https://example.com >"$logfile" 2>&1 &
pid=$!
sleep 4
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null
  exit_code=143
else
  wait "$pid"
  exit_code=$?
fi
cat "$logfile"
rm -f "$logfile"
if [ "$exit_code" -eq 0 ] || [ "$exit_code" -eq 143 ]; then
  exit 0
fi
exit "$exit_code"
```

Проверить, что после smoke не остался процесс:

```bash
pgrep -fl SafeScreenStage0 || true
```

## Ручная проверка UI

Запуск:

```bash
cd /Users/igor/projects/safescreen
swift run SafeScreenStage0 -- https://example.com
```

Проверить:

- окно открывается и показывает страницу;
- адресная строка загружает `https://...`;
- back, forward и reload работают;
- `Option+Shift+S` прячет и возвращает окно;
- Dock-иконка Stage 0 не появляется;
- закрытие окна не завершает процесс, повторный hotkey возвращает окно.

## Проверка фокуса

Цель: убедиться, что passive read/scroll не вызывает `blur` у страницы в основном браузере.

Сценарий:

- открыть в основном браузере тестовую страницу с логом `focus`, `blur` и `visibilitychange`;
- активировать основной браузер;
- открыть `SafeScreenStage0`;
- читать и скроллить страницу внутри `SafeScreenStage0`;
- проверить, что основной браузер не получил `blur`;
- отдельно кликнуть в адресную строку или поле ввода внутри `SafeScreenStage0` и зафиксировать, что
  ввод может вызвать `blur`.

## Проверка screen-share

Google Meet Web:

- открыть Meet в основном браузере;
- запустить `SafeScreenStage0`;
- включить демонстрацию полного экрана или окна из Meet;
- проверить на стороне зрителя или preview, что окно `SafeScreenStage0` не попадает в шаринг.

Zoom Web:

- открыть Zoom Web в основном браузере;
- повторить тот же сценарий screen-share;
- не использовать десктопный Zoom как целевой тест для `NSWindow.sharingType = .none`.

Если Google Meet Web или Zoom Web показывают окно Stage 0 несмотря на `sharingType = .none`, этап 0
считается неподтвержденным и приоритет возвращается к SafeScreen Display.

## Рабочее дерево и коммит

Перед финалом задачи:

```bash
cd /Users/igor/projects/safescreen
git status --short
git diff --check
```

Коммитить только файлы текущей задачи:

```bash
git add -- <paths>
git commit -m "<message>"
```
