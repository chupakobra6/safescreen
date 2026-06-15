# Ранбук Overlay Browser

Назначение: хранить команды запуска, сборки, проверки и ручные сценарии для текущего приложения
Overlay Browser.

## Среда

- Рабочая директория: `/Users/igor/projects/safescreen`.
- Кодовый путь: SwiftPM через Command Line Tools, без обязательного Xcode GUI.
- Минимальная платформа пакета: macOS 14.
- Основной executable product: `OverlayBrowser`.

Проверить окружение:

```bash
cd /Users/igor/projects/safescreen
swift --version
xcode-select -p
```

## Запуск

Запустить с URL:

```bash
cd /Users/igor/projects/safescreen
swift run OverlayBrowser -- https://example.com
```

Запустить без URL:

```bash
cd /Users/igor/projects/safescreen
swift run OverlayBrowser
```

Поведение:

- без URL открывается встроенная стартовая страница;
- URL без схемы нормализуется в `https://...`;
- `Option+Shift+S` показывает или прячет окно;
- дефолтный размер окна - `1280x800`, минимальный размер - `980x640`;
- чтение и скролл работают без клавиаточного input mode;
- клик в адресную строку или содержимое `WKWebView` переводит окно в input mode;
- hover внутри `WKWebView` остается на default cursor, включая ссылки и текстовые поля;
- страницы не должны издавать звук через обычные `audio`/`video` и Web Audio пути;
- `Escape` выводит окно из input mode;
- закрытие окна не завершает процесс.

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
find . -maxdepth 3 \( -path ./.git -o -path ./.build -o -name .DS_Store \) -prune -o -type f -print | sort
```

## Smoke-запуск без зависания терминала

Команда собирает и запускает `OverlayBrowser`, ждет несколько секунд, затем останавливает процесс.
Она нужна как быстрый sanity-check старта GUI из агента.

```bash
cd /Users/igor/projects/safescreen
logfile=$(mktemp /tmp/overlay-browser-smoke.XXXXXX)
swift run OverlayBrowser -- https://example.com >"$logfile" 2>&1 &
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
pgrep -fl OverlayBrowser || true
```

## Ручная проверка UI

Запуск:

```bash
cd /Users/igor/projects/safescreen
swift run OverlayBrowser -- https://example.com
```

Проверить:

- окно открывается и показывает страницу;
- адресная строка загружает `https://...`;
- back, forward и reload работают;
- `Option+Shift+S` прячет и возвращает окно;
- при hover над ссылками и текстовыми полями внутри страницы системный курсор остается стрелкой;
- invalid URL в адресной строке не издает системный beep;
- закрытие окна не завершает процесс, повторный hotkey возвращает окно.

## Проверка window privacy

Системный инвариант privacy-поведения: окно `Overlay Browser` должно иметь
`CGWindowSharingState == 0`. Это проверяет настройку macOS window sharing/capture API, которую
обычно используют звонки и демонстрация экрана. Проект не скрывает процесс или окно от локальных
приложений.

```bash
cd /Users/igor/projects/safescreen
swift run OverlayBrowser -- https://example.com >/tmp/overlay-browser-privacy.log 2>&1 &
pid=$!
sleep 4
swift -e 'import CoreGraphics; let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]; let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []; let matches = windows.filter { ($0[kCGWindowOwnerName as String] as? String) == "OverlayBrowser" }; guard let window = matches.first else { print("windowFound=false"); exit(1) }; print("windowFound=true"); print("sharingState=\(window[kCGWindowSharingState as String] ?? "missing")")'
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
```

Ожидаемый результат:

```text
windowFound=true
sharingState=0
```

## Проверка персистентности профиля

Сценарий:

- запустить `OverlayBrowser` с тестовым сайтом, который устанавливает cookie или localStorage;
- выполнить действие, которое сохраняет состояние в сайте;
- закрыть процесс приложения;
- запустить `OverlayBrowser` повторно с тем же URL;
- проверить, что сайт видит сохраненное состояние без повторной настройки.

Быстрая проверка WebKit API:

```bash
swift -e 'import Foundation; import WebKit; let id = UUID(uuidString: "4B801A03-C12C-4C5C-89CE-28D85E385B77")!; let store = WKWebsiteDataStore(forIdentifier: id); print("persistent=\(store.isPersistent)"); print("identifierMatches=\(store.identifier == id)")'
```

Ожидаемый результат:

```text
persistent=true
identifierMatches=true
```

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
