# Правила архивного Windows-подпроекта Overlay Browser

Назначение: сохранить технические инварианты одноразового Windows-прототипа без объявления его
поддерживаемым продуктом.

## Область

- Этот файл действует для всей папки `Windows/`.
- Общие правила репозитория находятся в [../AGENTS.md](../AGENTS.md).
- Windows-версия архивирована: исходники сохранены для справки, автоматический workflow удален,
  готовые сборки не выпускаются.
- Не изменять и не реактивировать подпроект без прямой просьбы пользователя.
- Техническое устройство Windows-версии описано в [README.md](README.md) и
  [../docs/architecture.md](../docs/architecture.md).
- Сохраненные ручные команды находятся в [../docs/runbook.md](../docs/runbook.md).

## Инварианты поведения

- Окно показывается без активации через `SW_SHOWNOACTIVATE`/`SWP_NOACTIVATE`; показ по hotkey не
  должен переводить foreground focus с игры, звонка или основного браузера.
- Не добавлять постоянный `WS_EX_NOACTIVATE`: он ломает обычный текстовый ввод в WebView2. Фокус
  разрешен только после явного клика пользователя внутри overlay.
- `Escape` выводит окно из input mode и возвращает focus окну, которое было foreground перед кликом
  по overlay.
- `WDA_EXCLUDEFROMCAPTURE` применяется к top-level HWND и тут же проверяется через
  `GetWindowDisplayAffinity`. При ошибке приложение работает fail-closed и не показывает обычное
  overlay window как защищенное.
- Приложение не скрывает процесс, не обходит игры и не подавляет системные события hotkey.
- Горячие клавиши - точные пары `Left Alt+Left Shift` и `Right Alt+Right Shift`. Low-level hook всегда
  передает события дальше через `CallNextHookEx`.
- Одна пара клавиш дает одно переключение до отпускания пары. Input mode не должен требовать первого
  отдельного нажатия для снятия фокуса перед скрытием.
- `Ctrl+V` внутри WebView2 остается нативным Windows paste path и не перехватывается приложением,
  чтобы текст и изображения не вставлялись дважды.
- WebView2 всегда muted на уровне `CoreWebView2.IsMuted`; document-start script дополнительно глушит
  `audio`/`video`. Не патчить `AudioContext` без отдельного подтвержденного требования.
- Профиль WebView2 постоянный и хранится в `%LOCALAPPDATA%\OverlayBrowser\WebView2`.
- Дефолтный URL - `https://chatgpt.com/`; стартовый client size - `420x820`; окно resizable и
  располагается справа как sidebar.
- Расширение `OverlayFocusGuard` общее для macOS и Windows. Не создавать отдельную копию extension
  внутри `Windows/`.

## Сохраненная проверка

Сохраненные PowerShell-команды locked restore, format, unit tests, solution build, publish и self-test
находятся в архивных разделах документа
[../docs/runbook.md](../docs/runbook.md#архив-windows-запуск-и-проверка). Не копировать их в новые
документы или scripts без отдельной причины.

Self-test обязан подтвердить Windows build, наличие WebView2 Runtime и exact affinity `0x00000011`.
Он проверяет системную настройку окна, но не заменяет ручную демонстрацию полного экрана в Chrome или
Edge.

## Условия реактивации

- При изменении NuGet dependencies обновлять соответствующий `packages.lock.json` командой
  обновления lock graph из runbook, затем снова проверять locked restore.
- При реактивации output, runtime identifier и имя executable должны оставаться синхронными с
  [installer/OverlayBrowser.Windows.iss](installer/OverlayBrowser.Windows.iss).
- Автоматического Windows CI и поддерживаемых `OverlayBrowser-Windows-x64.zip`/
  `OverlayBrowser-Windows-x64-Setup.exe` больше нет. Новый workflow требует отдельного решения.
- Не считать cross-build на macOS доказательством реального focus/capture поведения Win32. Для этого
  обязательны Windows self-test и один ручной screen-share smoke test из [README.md](README.md).
