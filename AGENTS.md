# AGENTS.md

## Project Overview
- SafeScreen - macOS-приложение для приватной демонстрации экрана.
- Пользователь шарит не реальный монитор, а SafeScreen output.
- Снаружи это должно выглядеть как обычный full-screen share.
- В shared-картинку попадают только разрешенные окна/приложения.
- Приватные окна, уведомления, реальные Dock/menu bar признаки, desktop files и отвлекающие
  приложения в output не попадают.

## Source Of Truth
- Архитектура и уровни разработки: `docs/architecture.md`
- Inbox с прямыми инпутами: `materials/inbox/`
- Текущие direct-chat deltas: `materials/inbox/2026-06-11-direct-chat-prompts.md`

## Product Constraints
- Этап 0 - быстрый прототип собственного браузера/overlay на macOS, который скрывает только свое
  окно от браузерных звонилок и проверяет спрос до сложного SafeScreen Display.
- Основное направление продукта - SafeScreen Display: виртуальный дисплей/output, который
  браузерная звонилка или OBS выбирает как full-screen source.
- Invisible overlay не является основным режимом: цель проекта - скрывать разные выбранные
  окна/приложения в разных звонках.
- Activity Monitor пока не трогаем.
- Браузерный benchmark нужен для проверки того, что web-звонилка видит только SafeScreen output.
- Звук - отдельный будущий трек после видео; не смешивать его с первыми уровнями разработки.
- Активные документы должны быть короткими и описывать текущее решение, а не хранить историю
  обсуждения.
- В проекте нет `README.md`; рабочая навигация идет через `AGENTS.md` и `docs/architecture.md`.

## Inbox и Igor Deltas
- Прямые сообщения Игоря с новыми требованиями, идеями или решениями сохраняются в
  `materials/inbox/YYYY-MM-DD-direct-chat-prompts.md`.
- Большие вставки и экспорты обсуждений сохраняются в `materials/inbox/` как Markdown.
- Прямые инструкции Игоря важнее старых выводов ассистента и внешних ответов.
- Поздняя прямая инструкция важнее ранней, если они конфликтуют.
- Активные документы описывают текущее решение, а не всю историю обсуждения.
- Перед финалом задачи сверять свежие inbox-deltas с реально измененными файлами.

## Commands
- Inspect project files: `find . -maxdepth 3 -type f | sort`
- Check worktree: `git status --short`
- Current state: documentation only, no app build commands yet.

## Documentation Boundaries
- `AGENTS.md` хранит короткие стабильные правила для будущих сессий.
- `docs/architecture.md` хранит архитектуру, уровни разработки и текущую продуктовую форму.
- `materials/inbox/` хранит raw-входы Игоря и normalized deltas.
- Не создавать новый документ, если смысл уже помещается в один из этих трех owners.
- Inbox-файлы ведутся в Markdown (`.md`).

## Verification
- Для документных правок проверять `git status --short`.
- Для изменений структуры проверять `find . -maxdepth 3 -type f | sort`.
- Для inbox-правок проверять, что direct-chat файл содержит только сообщения Игоря, без ответов
  ассистента и полного transcript.
- Для архитектурных правок сверять `docs/architecture.md` с последними normalized deltas.

## Knowledge Capture
- В `AGENTS.md` добавляются только короткие правила, которые будут полезны в будущих задачах.
- Длинная история обсуждения остается в `materials/inbox/` и git history.
- Старые решения в активных документах заменяются текущим состоянием, а не накапливаются рядом.
