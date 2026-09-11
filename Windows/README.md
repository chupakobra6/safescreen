# Архив Windows-версии Overlay Browser

Назначение: сохранить исходный код и технический контекст одноразового Windows-прототипа Overlay
Browser.

## Статус архива

Основной и единственный поддерживаемый продукт репозитория — macOS-приложение `OverlayBrowser`.
Windows-прототип был создан для разовой помощи, больше не развивается и не выпускается. Его исходники,
тесты и installer contract сохранены для справки; GitHub Actions workflow удален. Команды ниже нужны
только для ручного исследования архива или явно согласованной реактивации.

## Что было реализовано

`OverlayBrowser.Windows` - отдельное приложение на C#/.NET 10, WinForms, WebView2 и Win32. Оно не
зависит от Swift-кода во время выполнения, но повторяет основной контракт macOS-версии:

- открывает `https://chatgpt.com/` по умолчанию и принимает `http`/`https` URL первым аргументом;
- хранит cookie, login и website data в постоянном WebView2-профиле;
- стартует справа с client size `420x820` и свободно ресайзится;
- остается topmost, показывается без активации и не забирает foreground focus по hotkey;
- принимает обычный ввод и нативный `Ctrl+V` после явного клика внутри окна;
- возвращает focus предыдущему окну по `Escape`;
- переключается точными парами `Left Alt+Left Shift` и `Right Alt+Right Shift`;
- полностью mute-ит WebView2 и фиксирует arrow cursor внутри страниц;
- устанавливает и проверяет `WDA_EXCLUDEFROMCAPTURE`, а при ошибке закрывается fail-closed;
- прячется кнопкой закрытия, остается запущенным в tray и имеет tray-команду `Exit`;
- не допускает два параллельных экземпляра: повторный запуск показывает уже работающий overlay.

Расширение основного браузера не дублируется: Windows использует общую папку
`Extensions/OverlayFocusGuard`.

## Архивный способ сборки

Автоматические артефакты больше не собираются. Сохраненный installer contract создавал
`OverlayBrowser-Windows-x64-Setup.exe`, который:

- ставит приложение для текущего пользователя в `%LOCALAPPDATA%\Programs\OverlayBrowser`;
- добавляет shortcut в Start menu;
- запускает официальный Microsoft WebView2 Evergreen bootstrapper;
- не требует отдельной установки .NET, потому что приложение публикуется self-contained.

Installer пока не подписан, поэтому Windows SmartScreen может показать предупреждение неизвестного
издателя. Это ограничение дистрибуции, а не результат self-test.

Архивный portable-вариант назывался `OverlayBrowser-Windows-x64.zip`; для его запуска требовался
WebView2 Runtime.

## Self-test

Запустить published executable в режиме `--self-test` по канонической команде из
[runbook](../docs/runbook.md#windows-publish-и-self-test).

Успешный результат содержит четыре `PASS`:

```text
[PASS] windows-version: ...
[PASS] webview2-runtime: ...
[PASS] url-policy: ...
[PASS] window-capture-exclusion: WDA_EXCLUDEFROMCAPTURE is active. affinity=0x00000011 error=0
Self-test passed.
```

Лог приложения находится в `%LOCALAPPDATA%\OverlayBrowser\logs\overlay-browser.log`.

## Обязательный ручной screen-share smoke test

Self-test подтверждает, что Windows приняла и вернула exact affinity `0x00000011`, но реальный путь
захвата конкретной звонилки проверяется один раз на целевой машине:

1. Запустить Overlay Browser и оставить его поверх обычного окна с заметным содержимым.
2. В Chrome или Edge открыть используемую браузерную звонилку.
3. Включить демонстрацию `Entire screen`/`Весь экран`, не отдельной вкладки.
4. Посмотреть preview демонстрации или попросить второго участника подтвердить результат.
5. Убедиться, что desktop и обычные окна видны, а Overlay Browser отсутствует в capture.
6. Нажать оба hotkey, проверить показ/скрытие одним срабатыванием и отсутствие паузы/потери focus у
   foreground-приложения при простом показе overlay.
7. Кликнуть в ChatGPT, проверить текст и одну вставку через `Ctrl+V`; затем нажать `Escape` и
   убедиться, что focus вернулся в предыдущее окно.

Если overlay виден в browser screen share, не продолжать использование в звонке. Сохранить версию
Windows, Chrome/Edge, название звонилки и приложить основной log агенту.

## Ручное восстановление

Требования:

- Windows 10 version 2004 (`10.0.19041`) или новее; предпочтительно Windows 11;
- .NET 10 SDK для разработки;
- WebView2 Evergreen Runtime для запуска;
- Node.js 24 только для extension E2E.

Сохраненные команды локального прогона и publish находятся в архивных Windows-разделах
[runbook](../docs/runbook.md#архив-windows-запуск-и-проверка). Перед изменением shell также прочитать
[AGENTS.md](AGENTS.md), где зафиксированы fail-closed, focus и hotkey инварианты.

## Структура

| Путь | Ответственность |
| --- | --- |
| `src/OverlayBrowser.Windows.Core` | Тестируемые на macOS/Windows URL, hotkey state и browser scripts. |
| `src/OverlayBrowser.Windows` | WinForms/WebView2 shell, Win32 privacy/focus/hotkey и self-test. |
| `tests/OverlayBrowser.Windows.Tests` | Переносимые unit-тесты без реального Windows desktop. |
| `installer/OverlayBrowser.Windows.iss` | Inno Setup installer и WebView2 bootstrapper contract. |

## Границы гарантии

`WDA_EXCLUDEFROMCAPTURE` предназначен для публичных системных capture API Windows и типичного
browser screen sharing. Он не скрывает процесс или HWND от локальных программ и не является защитой
от камеры, драйверного/аппаратного захвата либо программы, которая намеренно игнорирует стандартный
capture path.

Пары `Alt+Shift` не подавляются и поэтому могут совпасть с пользовательской системной комбинацией
смены раскладки. Это осознанно: overlay не должен перехватывать или скрывать клавиатурные события от
Windows и игр. Менять Windows hotkey следует только как отдельное продуктовое решение.
