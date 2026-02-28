# 01-onboard

Интерактивный bootstrap-скрипт для быстрого onboarding серверов. Одна команда — полностью настроенный терминал с современными CLI-утилитами.

![Bash](https://img.shields.io/badge/bash-%23121011.svg?style=flat&logo=gnu-bash&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-A81D33?style=flat&logo=debian&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)
![Alpine](https://img.shields.io/badge/Alpine-0D597F?style=flat&logo=alpine-linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Kirorus/01-onboard/main/setup.sh)
```

> Используется `bash <(...)` вместо `curl | bash`, чтобы TUI-меню могло читать ввод с клавиатуры.

## Как это работает

Скрипт показывает интерактивное TUI-меню в два шага:

**Шаг 1** — выбор компонентов для установки:

```
╔════════════════════════════════════════════════╗
║         HomeLab Server Bootstrap               ║
╚════════════════════════════════════════════════╝

  Выберите компоненты для установки:

  ▶ [x] Core CLI        zsh + starship, eza, bat, fzf, ripgrep, fd, zoxide
    [x] System Utils    btop, ncdu, duf, delta, jq, yq, mc, nano
    [x] Multiplexer     ○ tmux  ● zellij
    [x] Git Tools       lazygit
    [ ] Docker          Docker Engine + Docker Compose
    [ ] Dockge          Docker Compose UI (требует Docker)
    [ ] Tailscale       VPN через Headscale (ts.kiroru.ru)
    [ ] code-server     VS Code в браузере

    ─────────────────────────────────
    [ ] Dry-run         показать план без установки

  ↑↓ – перемещение   SPACE – вкл/выкл   ←→ – tmux/zellij   ENTER – установить   q – выход
```

**Шаг 2** — выбор цвета Starship prompt (тип сервера):

```
  Тип сервера (цвет строки статуса):

  ▶ ● Proxmox      █████  #ff8400
    ● VPS          █████  #f38ba8
    ● Ubuntu/Deb   █████  #e95420
    ● Alpine       █████  #0d597f
    ● Docker host  █████  #2496ed
    ● macOS        █████  #a6e3a1
    ● Windows      █████  #89dceb
    ● NAS/Storage  █████  #cba6f7
    ● Custom       ввести свой hex (#rrggbb)
```

Цвет подставляется в `segment0` палитры Catppuccin Mocha в `starship.toml` — так по prompt сразу видно, на каком типе сервера ты находишься.

## Компоненты

### Core CLI (по умолчанию вкл)

| Утилита | Описание |
|---------|----------|
| [zsh](https://www.zsh.org/) | Shell + autosuggestions + syntax-highlighting |
| [Starship](https://starship.rs/) | Prompt с Catppuccin Mocha |
| [eza](https://github.com/eza-community/eza) | Замена `ls` с иконками и git-статусом |
| [bat](https://github.com/sharkdp/bat) | Замена `cat` с подсветкой синтаксиса |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Быстрый `grep` |
| [fd](https://github.com/sharkdp/fd) | Быстрый `find` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Умный `cd` |

Устанавливает dotfiles: `.zshrc`, `.bash_aliases`, `starship.toml`. Существующие файлы сохраняются в `.bak`.

### System Utils (по умолчанию вкл)

| Утилита | Описание |
|---------|----------|
| [btop](https://github.com/aristocratos/btop) | Монитор ресурсов |
| [ncdu](https://dev.yorhel.nl/ncdu) | Анализ дискового пространства |
| [duf](https://github.com/muesli/duf) | Замена `df` |
| [delta](https://github.com/dandavison/delta) | Красивый `diff` |
| [jq](https://jqlang.github.io/jq/) | JSON-процессор |
| [yq](https://github.com/mikefarah/yq) | YAML-процессор |
| [mc](https://midnight-commander.org/) | Файловый менеджер |
| nano | Текстовый редактор |

### Multiplexer (по умолчанию вкл, один из двух)

- **tmux** — классический терминальный мультиплексер
- **zellij** — современная альтернатива tmux

Переключается стрелками ←→ в меню.

### Git Tools (по умолчанию вкл)

- [lazygit](https://github.com/jesseduffield/lazygit) — TUI для git

### Docker (опционально)

Docker Engine + Docker Compose. На Debian/Ubuntu через [get.docker.com](https://get.docker.com), на Alpine через `apk`.

На macOS устанавливается Docker Desktop (через Homebrew Cask).

### Dockge (опционально)

[Dockge](https://github.com/louislam/dockge) — веб-UI для управления Docker Compose стеками. Требует Docker. Запускается на порту `5001`.

### Tailscale (опционально)

Устанавливает Tailscale и подключает к Headscale-серверу `ts.kiroru.ru`. Скрипт покажет URL для авторизации.

### code-server (опционально)

[code-server](https://github.com/coder/code-server) — VS Code в браузере. Слушает на `0.0.0.0:8080`. Пароль генерируется автоматически и выводится в конце установки.

## Опции CLI

```
bash setup.sh [OPTIONS]

  --user=NAME   Целевой пользователь (при запуске от root)
  --dry-run     Показать план без установки
  --help        Справка
```

## Поддерживаемые платформы

| | Пакетный менеджер | Init-система | Архитектуры |
|-|-------------------|-------------|-------------|
| Debian / Ubuntu | apt | systemd | x86_64, aarch64 |
| Alpine | apk | OpenRC | x86_64, aarch64 |
| macOS | brew | launchd (без авто-настройки) | x86_64, arm64 |

## Структура

```
├── setup.sh              # Основной скрипт
└── dotfiles/
    ├── .zshrc            # Конфиг zsh
    ├── .bash_aliases     # Алиасы для bash
    └── starship.toml     # Starship prompt (Catppuccin Mocha)
```

## Dry-run

Посмотреть что будет установлено без реальных изменений:

```bash
# Через CLI-флаг
bash setup.sh --dry-run

# Или включить пункт Dry-run в меню
```

Вывод:

```
╔════════════════════════════════════════════════╗
║              DRY-RUN — план действий           ║
╚════════════════════════════════════════════════╝

  Система:     debian 12 (x86_64)
  Пользователь: kiroru (/home/kiroru)
  Пакетный мгр: apt

  ✓ Core CLI       — zsh, starship, eza, bat, fzf, ripgrep, fd, zoxide
                     Цвет Starship: #ff8400
                     Конфиги: .zshrc, .bash_aliases, starship.toml
  ✓ System Utils   — btop, ncdu, duf, delta, jq, yq, mc, nano
  ✓ Multiplexer    — tmux
  ✓ Git Tools      — lazygit
```
