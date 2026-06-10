# Browser Benchmark

Браузерный прокторинг или агрессивная браузерная звонарка могут быть полезным тестовым стендом, но
не должны становиться обещанием продукта. Этот benchmark проверяет только то, что получает web page
через браузерные APIs и выбранный пользователем screen-share source.

## Что benchmark доказывает

- Браузерный `getDisplayMedia` получает SafeScreen output, а не реальный приватный desktop.
- Captured stream не содержит скрытые окна, уведомления, настоящий Dock/menu bar и приватные
  desktop files.
- SafeScreen source выглядит для браузера как monitor/display source на уровне Stage 2.
- Приложение правильно ведет пользователя через source picker.

## Что benchmark не доказывает

- Что нативная звонарка не может запросить Screen Recording permission и снять реальный экран.
- Что локальный корпоративный агент не видит фокус, процессы или UI через Accessibility/MDM.
- Что сайт не узнает собственные browser events вроде `visibilitychange`, `focus` или `blur`.
- Что SafeScreen можно использовать для обхода прокторинга.

## Test harness

На первом уровне нужен локальный тестовый сайт:

```text
http://localhost:<port>/benchmark
```

Минимальные функции:

- кнопка `Start screen capture`;
- показ выбранного stream resolution/FPS;
- запись 10-30 секунд captured video;
- frame sampling для поиска запрещенных цветовых маркеров/test patterns;
- лог browser-visible events:
  - `visibilitychange`;
  - `focus`;
  - `blur`;
  - fullscreen enter/exit;
  - track mute/unmute/ended;
  - resize/orientation-like changes where applicable.

## Stage 1 checklist

- Share SafeScreen preview window.
- Открыть приватное окно поверх реального экрана.
- Переключить фокус на приватное приложение.
- Получить запись из benchmark page.
- Проверить, что запись не содержит приватные пиксели.
- Сохранить результат как локальный artifact в ignored `recordings/` или `captures/`.

## Stage 2 checklist

- Browser picker показывает `SafeScreen` как entire-screen/monitor source.
- Пользователь выбирает именно `SafeScreen`.
- Benchmark пишет captured stream.
- Проверяется отсутствие:
  - приватных окон;
  - настоящего Dock;
  - настоящего menu bar;
  - notification banners;
  - desktop files;
  - признаков скрытых приложений в SafeScreen chrome.
- В отчете отдельно указывается, какие browser events страница увидела.

## Compatibility matrix

| Target | Stage | Result fields |
| --- | --- | --- |
| Chrome + local benchmark | 1, 2 | source type, resolution, FPS, leak scan, event log |
| Safari + local benchmark | 2 | source availability, resolution, FPS, event log |
| Google Meet web | 2 | remote recording review, UI friction |
| Zoom web client | 2 | remote recording review, UI friction |
| OBS browser/window capture | 1, 2 | source behavior, frame pacing |

## Reporting format

Каждый серьезный прогон должен отвечать на пять вопросов:

1. Какой source был выбран пользователем?
2. Какая версия macOS, браузера и SafeScreen?
3. Что было скрыто?
4. Есть ли визуальные лики в записи?
5. Какие browser-observable events были зафиксированы?
