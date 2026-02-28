# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор

Bootstrap-скрипт для onboarding новых серверов. Интерактивное TUI-меню для выбора компонентов, поддержка Debian/Ubuntu и Alpine.

## Запуск

```bash
# Удалённо (с GitHub)
bash <(curl -fsSL https://raw.githubusercontent.com/Kirorus/01-onboard/main/setup.sh)

# Локально
bash setup.sh

# Dry-run (только план)
bash setup.sh --dry-run
```

## Проверка после изменений

```bash
bash -n setup.sh
```

## Конвенции

- Язык документации и UI: русский
- Shell: `#!/usr/bin/env bash`, `set -euo pipefail`
- Коммиты: conventional commits на английском (`feat:`, `fix:`, `docs:`)
- TUI-меню: только ANSI escape codes + `read`, без внешних зависимостей (no whiptail/dialog)
- Поддержка двух платформ: apt + systemd (Debian/Ubuntu) и apk + OpenRC (Alpine)

## GitHub

Репозиторий: `git@github.com:Kirorus/01-onboard.git`, ветка `main`.
