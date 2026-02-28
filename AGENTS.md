# AGENTS.md

Руководство для AI-агентов, работающих с bootstrap-скриптом `setup.sh`.

## Что это

Интерактивный Bash-скрипт для onboarding. TUI-меню на ANSI escape codes (без whiptail/dialog). Поддерживает Debian/Ubuntu (apt, systemd), Alpine (apk, OpenRC) и macOS (brew).

Запускается двумя способами:
- **Удалённо**: `bash <(curl -fsSL ...)` — dotfiles скачиваются с GitHub
- **Локально**: из клона репо — dotfiles берутся из `./dotfiles/`

## Структура

```
01-onboard/
├── setup.sh           # Основной скрипт (~500 строк)
└── dotfiles/
    ├── .zshrc         # Конфиг zsh (плагины, алиасы, интеграции)
    ├── .bash_aliases  # Алиасы для bash (eza, bat, fzf, zoxide)
    └── starship.toml  # Prompt Starship (Catppuccin Mocha, кастомный segment0)
```

## Валидация после изменений

```bash
# Синтаксис (обязательно)
bash -n 01-onboard/setup.sh

# Dry-run (проверка логики без установки)
bash 01-onboard/setup.sh --dry-run
```

Юнит-тестов нет. Главная проверка — `bash -n` + dry-run.

## Архитектура setup.sh

1. **CLI-аргументы**: `--user=NAME`, `--dry-run`, `--help`
2. **Определение окружения**: ОС (`/etc/os-release`), архитектура (`x86_64`/`aarch64`), пользователь (root или обычный)
3. **TUI шаг 1**: выбор цвета Starship (тип сервера) — стрелки ↑↓, Enter
4. **TUI шаг 2**: выбор компонентов — чекбоксы (Space вкл/выкл), радио для мультиплексера (←→), Enter
5. **Установка**: пакеты apt/apk → бинарники с GitHub → curl-инсталлеры → конфиги → сервисы
6. **Итоговый вывод**: summary с паролями и инструкциями

### Ключевые функции

- `select_color()` / `select_components()` — TUI-меню через ANSI escape codes и `read -rsn1`
- `install_github_bin(name, repo, url_template)` — скачивает latest release с GitHub, распаковывает в `/usr/local/bin/`
- `get_latest_tag(repo)` — GitHub API для получения последней версии
- `deploy_file(src, dst)` — копирует файл с бэкапом существующего (`.bak.TIMESTAMP`)
- `fetch_dotfile(name, dest)` — берёт dotfile локально или с GitHub (зависит от `LOCAL_MODE`)
- `pkg_install()` / `pkg_update()` — обёртки над apt/apk

### Компоненты (массив COMP_SELECTED)

| Индекс | Компонент    | По умолчанию | Что устанавливает |
|--------|-------------|-------------|-------------------|
| 0      | Core CLI    | вкл         | zsh, starship, eza, bat, fzf, ripgrep, fd, zoxide + dotfiles |
| 1      | System Utils| вкл         | btop, ncdu, duf, delta, jq, yq, mc, nano |
| 2      | Multiplexer | вкл         | tmux ИЛИ zellij (переключается `MUX_CHOICE`) |
| 3      | Git Tools   | вкл         | lazygit |
| 4      | Docker      | выкл        | Docker Engine + Compose |
| 5      | Dockge      | выкл        | Docker Compose UI (зависит от Docker) |
| 6      | Tailscale   | выкл        | VPN → Headscale ts.kiroru.ru |
| 7      | code-server | выкл        | VS Code в браузере, 0.0.0.0:8080 |
| 8      | Dry-run     | выкл        | Показать план без установки |

## Правила для агентов

### Shell-код
- `set -euo pipefail` — не убирать
- Все переменные в кавычках: `"$VAR"`, не `$VAR`
- Для всех платформ: apt **и** apk **и** brew; systemd **и** OpenRC (на macOS без systemd/OpenRC)
- Имена пакетов различаются: `fd-find` (apt) vs `fd` (apk), `bat` (apk) vs `bat`→`batcat` (apt)
- `chsh` на Alpine требует пакет `shadow`
- `getent` может отсутствовать — есть fallback через `grep /etc/passwd`

### TUI-меню
- Только ANSI escape codes + `read` + `tput` — никаких внешних зависимостей
- Курсор скрывается (`\033[?25l`) и восстанавливается (`\033[?25h`) через trap
- Стрелки читаются как escape sequences: `\033[A`, `\033[B`, `\033[C`, `\033[D`

### GitHub releases
- URL-шаблоны содержат `${VER}`, `${ARCH_MU}`, `${ARCH_GO}` — подставляются через `eval echo`
- Rate limit: 60 запросов/час без токена — хватает на 5-6 вызовов `get_latest_tag()`

### Безопасность
- Не коммитить реальные пароли/токены
- `CS_PASSWORD` генерируется на сервере, не хранится в репо
- Tailscale подключается к приватному Headscale (ts.kiroru.ru)

### Dotfiles
- Изменения в dotfiles должны работать и в zsh, и в bash (алиасы дублируются)
- `starship.toml` использует кастомный цвет `segment0` в палитре `catppuccin_mocha`
- Цвет подставляется через `sed` после копирования конфига
