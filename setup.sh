#!/usr/bin/env bash
# HomeLab Server Bootstrap
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/Kirorus/01-onboard/main/setup.sh)
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
GITHUB_RAW="https://raw.githubusercontent.com/Kirorus/01-onboard/main"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -d "$SCRIPT_DIR/dotfiles" ]; then
    LOCAL_MODE=1
else
    LOCAL_MODE=0
fi

# ── CLI args ─────────────────────────────────────────────────────────────────
ARG_USER=""
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --user=*) ARG_USER="${arg#--user=}" ;;
        --dry-run) DRY_RUN=1 ;;
        --help)
            cat <<'HELP'
HomeLab Server Bootstrap

Usage:
  bash setup.sh [OPTIONS]
  bash <(curl -fsSL .../setup.sh) [OPTIONS]

Options:
  --user=NAME   Target user (when running as root)
  --dry-run     Show plan without installing
  --help        Show this help
HELP
            exit 0
            ;;
    esac
done

# ── Colored output ───────────────────────────────────────────────────────────
step()  { printf '\n\033[1;33m==> %s\033[0m\n' "$1"; }
ok()    { printf '  \033[0;32m[OK]\033[0m  %s\n' "$1"; }
skip()  { printf '  \033[1;33m[SKIP]\033[0m %s\n' "$1"; }
err()   { printf '  \033[0;31m[ERR]\033[0m  %s\n' "$1" >&2; }

# ── Environment detection ────────────────────────────────────────────────────
UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"

if [ "$(id -u)" = "0" ]; then
    TARGET_USER="${ARG_USER:-root}"
    if command -v getent >/dev/null 2>&1; then
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    else
        TARGET_HOME="$(grep "^${TARGET_USER}:" /etc/passwd | cut -d: -f6)"
    fi
    SUDO=""
else
    TARGET_USER="$USER"
    TARGET_HOME="$HOME"
    SUDO="sudo"
fi

if [ "$UNAME_S" = "Darwin" ] && [ "$(id -u)" = "0" ]; then
    err "macOS: не запускайте скрипт от root (запустите под обычным пользователем)"
    exit 1
fi

case "$UNAME_M" in
    x86_64)
        ARCH_MU="x86_64"
        ARCH_GO="amd64"
        ARCH_DUF="x86_64"
        ;;
    aarch64|arm64)
        ARCH_MU="aarch64"
        ARCH_GO="arm64"
        ARCH_DUF="arm64"
        ;;
    *) err "Unsupported architecture: $UNAME_M"; exit 1 ;;
esac

if [ "$UNAME_S" = "Darwin" ]; then
    ID="macos"
    VERSION_ID="$(sw_vers -productVersion 2>/dev/null || true)"
    PKG="brew"
else
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        err "/etc/os-release not found"; exit 1
    fi

    case "$ID" in
        debian|ubuntu) PKG="apt" ;;
        alpine)        PKG="apk" ;;
        *) err "Unsupported distro: $ID"; exit 1 ;;
    esac
fi

# Fix TARGET_HOME on platforms without getent/passwd entry (e.g. macOS)
if [ -z "${TARGET_HOME:-}" ]; then
    if [ "$UNAME_S" = "Darwin" ] && command -v dscl >/dev/null 2>&1; then
        TARGET_HOME="$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
    fi
fi
if [ -z "${TARGET_HOME:-}" ]; then
    err "Не удалось определить домашнюю директорию для пользователя: $TARGET_USER"
    exit 1
fi

# ── File fetcher ─────────────────────────────────────────────────────────────
fetch_dotfile() {
    local name="$1" dest="$2"
    if [ "$LOCAL_MODE" = "1" ]; then
        cp "$SCRIPT_DIR/dotfiles/$name" "$dest"
    else
        curl -fsSL "$GITHUB_RAW/dotfiles/$name" -o "$dest"
    fi
}

# ── Deploy with backup ───────────────────────────────────────────────────────
deploy_file() {
    local src="$1" dst="$2"
    if [ -f "$dst" ]; then
        local bak="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$dst" "$bak"
        ok "Бэкап: $bak"
    fi
    cp "$src" "$dst"
}

# ── sed inplace helper (GNU/BSD) ─────────────────────────────────────────────
sed_inplace() {
    local script="$1" file="$2"
    if [ "$UNAME_S" = "Darwin" ]; then
        sed -i '' "$script" "$file"
    else
        sed -i "$script" "$file"
    fi
}

# ── GitHub helpers ───────────────────────────────────────────────────────────
get_latest_tag() {
    curl -sf "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\?\([^"]*\)".*/\1/'
}

github_api_headers() {
    # Extra headers for GitHub API; uses GITHUB_TOKEN if present.
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        printf '%s\n' \
            "-H" "Authorization: Bearer ${GITHUB_TOKEN}" \
            "-H" "X-GitHub-Api-Version: 2022-11-28"
    else
        printf '%s\n' "-H" "X-GitHub-Api-Version: 2022-11-28"
    fi
}

get_release_asset_id() {
    local repo="$1" tag="$2" asset_name="$3"
    local url="https://api.github.com/repos/${repo}/releases/tags/${tag}"
    local body http
    body="$(curl -sSL -w '\n%{http_code}' -H 'Accept: application/vnd.github+json' $(github_api_headers) "$url" || true)"
    http="${body##*$'\n'}"
    body="${body%$'\n'*}"

    if [ "$http" != "200" ]; then
        # Try to surface rate-limit / error message.
        if echo "$body" | grep -q 'rate limit'; then
            err "GitHub API rate limit: задайте GITHUB_TOKEN для увеличения лимита"
        else
            err "GitHub API error ($http) при получении assets для ${repo}@${tag}"
        fi
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "$body" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .id' | head -n 1
        return 0
    fi

    # Fallback parser without jq (expects JSON with newlines).
    echo "$body" | awk -v target="$asset_name" '
        BEGIN { in_assets=0; cur_id="" }
        /"assets"[[:space:]]*:[[:space:]]*\[/ { in_assets=1; next }
        in_assets && /"id"[[:space:]]*:/ {
            if (match($0, /"id"[[:space:]]*:[[:space:]]*([0-9]+)/, m)) cur_id=m[1]
        }
        in_assets && $0 ~ "\"name\"" {
            if (index($0, "\"name\": \"" target "\"") > 0) { print cur_id; exit }
        }
    '
}

download_release_asset() {
    local repo="$1" tag="$2" asset_name="$3" dest="$4"
    local asset_id
    asset_id="$(get_release_asset_id "$repo" "$tag" "$asset_name")"
    if [ -z "${asset_id:-}" ]; then
        return 1
    fi
    local url="https://api.github.com/repos/${repo}/releases/assets/${asset_id}"
    local http
    http="$(curl -sSL -w '%{http_code}' -o "$dest" -H 'Accept: application/octet-stream' $(github_api_headers) "$url" || true)"
    if [ "$http" != "200" ]; then
        rm -f "$dest" 2>/dev/null || true
        return 1
    fi
}

download_url_with_github_fallback() {
    local repo="$1" url="$2" dest="$3"

    # Try direct download first.
    if curl -fsSL "$url" -o "$dest"; then
        return 0
    fi

    # Fallback: GitHub assets API (some networks return 404 on /releases/download/...).
    if echo "$url" | grep -qE '^https://github\.com/[^/]+/[^/]+/releases/download/[^/]+/[^/]+$'; then
        local tag asset
        tag="${url#*releases/download/}"
        tag="${tag%%/*}"
        asset="${url##*/}"

        if download_release_asset "$repo" "$tag" "$asset" "$dest"; then
            return 0
        fi
    fi

    return 1
}

install_github_bin() {
    local name="$1" repo="$2" url_template="$3"
    if command -v "$name" >/dev/null 2>&1; then
        skip "$name (уже установлен)"
        return
    fi
    local VER
    VER="$(get_latest_tag "$repo")"
    if [ -z "$VER" ]; then
        err "Не удалось получить версию $name"; return 1
    fi
    local RESOLVED_URL
    RESOLVED_URL="$(eval echo "$url_template")"
    local tmpdir
    tmpdir="$(mktemp -d)"
    ok "Скачиваю $name v$VER..."
    if echo "$RESOLVED_URL" | grep -qE '\.tar\.gz$|\.tgz$'; then
        if ! download_url_with_github_fallback "$repo" "$RESOLVED_URL" "$tmpdir/archive.tar.gz"; then
            err "Не удалось скачать $name (URL: $RESOLVED_URL)"; rm -rf "$tmpdir"; return 1
        fi
        tar xzf "$tmpdir/archive.tar.gz" -C "$tmpdir"
        local bin_path
        bin_path="$(find "$tmpdir" -name "$name" -type f | head -1)"
        if [ -z "$bin_path" ]; then
            err "Бинарник $name не найден в архиве"; rm -rf "$tmpdir"; return 1
        fi
        $SUDO install -m 755 "$bin_path" "/usr/local/bin/$name"
    else
        if ! download_url_with_github_fallback "$repo" "$RESOLVED_URL" "$tmpdir/$name"; then
            err "Не удалось скачать $name (URL: $RESOLVED_URL)"; rm -rf "$tmpdir"; return 1
        fi
        $SUDO install -m 755 "$tmpdir/$name" "/usr/local/bin/$name"
    fi
    rm -rf "$tmpdir"
    ok "$name v$VER установлен"
}

# ── Hex color helpers ────────────────────────────────────────────────────────
hex_to_rgb() {
    local hex="${1#\#}"
    printf '%d %d %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

ansi_fg() {
    local r g b
    read -r r g b <<< "$(hex_to_rgb "$1")"
    printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ── TUI: Color selection ────────────────────────────────────────────────────
COLOR_NAMES=(
    "Proxmox"
    "VPS"
    "Ubuntu/Deb"
    "Alpine"
    "Docker host"
    "macOS"
    "Windows"
    "NAS/Storage"
    "Custom"
)
COLOR_HEX=(
    "#ff8400"
    "#f38ba8"
    "#e95420"
    "#0d597f"
    "#2496ed"
    "#a6e3a1"
    "#89dceb"
    "#cba6f7"
    ""
)

select_color() {
    local selected=0
    local total=${#COLOR_NAMES[@]}
    local key

    # Hide cursor
    printf '\033[?25l'
    trap 'printf "\033[?25h"' RETURN

    while true; do
        # Clear and draw
        printf '\033[2J\033[H'
        printf '╔════════════════════════════════════════════════╗\n'
        printf '║         HomeLab Server Bootstrap               ║\n'
        printf '╚════════════════════════════════════════════════╝\n\n'
        printf '  Тип сервера (цвет строки статуса):\n\n'

        for i in $(seq 0 $((total - 1))); do
            local prefix="   "
            [ "$i" = "$selected" ] && prefix="  ▶"

            if [ "$i" -lt $((total - 1)) ]; then
                local hex="${COLOR_HEX[$i]}"
                local color_block
                color_block="$(ansi_fg "$hex")█████${RESET}"
                printf '%s ● %-14s %b  %s\n' "$prefix" "${COLOR_NAMES[$i]}" "$color_block" "$hex"
            else
                printf '%s ● %-14s ввести свой hex (#rrggbb)\n' "$prefix" "${COLOR_NAMES[$i]}"
            fi
        done

        printf '\n  ↑↓ – перемещение   ENTER – выбрать\n'

        # Read key
        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A') selected=$(( (selected - 1 + total) % total )) ;;
                    '[B') selected=$(( (selected + 1) % total )) ;;
                esac
                ;;
            '')
                # ENTER
                if [ "$selected" -eq $((total - 1)) ]; then
                    # Custom color
                    printf '\033[?25h'
                    printf '\n  Введите hex-цвет (#rrggbb): '
                    read -r custom_hex
                    if echo "$custom_hex" | grep -qE '^#[0-9a-fA-F]{6}$'; then
                        CHOSEN_COLOR="$custom_hex"
                    else
                        err "Неверный формат. Используется цвет по умолчанию #ff8400"
                        CHOSEN_COLOR="#ff8400"
                    fi
                else
                    CHOSEN_COLOR="${COLOR_HEX[$selected]}"
                fi
                return
                ;;
        esac
    done
}

# ── TUI: Component selection ────────────────────────────────────────────────
COMP_NAMES=(
    "Core CLI"
    "System Utils"
    "Multiplexer"
    "Git Tools"
    "Docker"
    "Dockge"
    "Tailscale"
    "code-server"
    "Dry-run"
)
COMP_DESC=(
    "zsh + starship, eza, bat, fzf, ripgrep, fd, zoxide"
    "btop, ncdu, duf, delta, jq, yq, mc, nano"
    "tmux / zellij"
    "lazygit"
    "Docker Engine + Docker Compose"
    "Docker Compose UI (требует Docker)"
    "VPN через Headscale (ts.kiroru.ru)"
    "VS Code в браузере"
    "показать план без установки"
)
COMP_SELECTED=(1 1 1 1 0 0 0 0 0)  # defaults
MUX_CHOICE=0  # 0=tmux, 1=zellij

select_components() {
    local selected=0
    local total=${#COMP_NAMES[@]}
    local sep_index=8  # Dry-run separator before index 8
    local key

    printf '\033[?25l'
    trap 'printf "\033[?25h"' RETURN

    while true; do
        printf '\033[2J\033[H'
        printf '╔════════════════════════════════════════════════╗\n'
        printf '║         HomeLab Server Bootstrap               ║\n'
        printf '╚════════════════════════════════════════════════╝\n\n'
        printf '  Выберите компоненты для установки:\n\n'

        for i in $(seq 0 $((total - 1))); do
            # Separator before dry-run
            if [ "$i" = "$sep_index" ]; then
                printf '    ─────────────────────────────────\n'
            fi

            local prefix="   "
            [ "$i" = "$selected" ] && prefix="  ▶"

            if [ "$i" = 2 ]; then
                # Multiplexer: radio toggle
                local mark="[x]"
                [ "${COMP_SELECTED[$i]}" = "0" ] && mark="[ ]"
                local mux_label
                if [ "$MUX_CHOICE" = "0" ]; then
                    mux_label="● tmux  ○ zellij"
                else
                    mux_label="○ tmux  ● zellij"
                fi
                printf '%s %s %-16s %s\n' "$prefix" "$mark" "Multiplexer" "$mux_label"
            else
                local mark="[x]"
                [ "${COMP_SELECTED[$i]}" = "0" ] && mark="[ ]"
                printf '%s %s %-16s %s\n' "$prefix" "$mark" "${COMP_NAMES[$i]}" "${COMP_DESC[$i]}"
            fi
        done

        printf '\n  ↑↓ – перемещение   SPACE – вкл/выкл   ←→ – tmux/zellij   ENTER – установить   q – выход\n'

        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A') selected=$(( (selected - 1 + total) % total )) ;;
                    '[B') selected=$(( (selected + 1) % total )) ;;
                    '[C'|'[D')
                        # ←→ — switch multiplexer variant
                        if [ "$selected" = 2 ] && [ "${COMP_SELECTED[2]}" = "1" ]; then
                            MUX_CHOICE=$(( 1 - MUX_CHOICE ))
                        fi
                        ;;
                esac
                ;;
            ' ')
                # SPACE — toggle on/off
                COMP_SELECTED[$selected]=$(( 1 - ${COMP_SELECTED[$selected]} ))
                ;;
            '')
                # ENTER — apply dry-run from menu if selected
                if [ "${COMP_SELECTED[8]}" = "1" ]; then
                    DRY_RUN=1
                fi
                printf '\033[?25h'
                return
                ;;
            q|Q)
                printf '\033[?25h'
                printf '\nОтменено.\n'
                exit 0
                ;;
        esac
    done
}

# ── Package install helpers ──────────────────────────────────────────────────
ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        return
    fi

    step "Homebrew"
    ok "Устанавливаю Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew не найден после установки"
        exit 1
    fi
    ok "Homebrew установлен"
}

pkg_install() {
    if [ "$PKG" = "brew" ]; then
        ensure_homebrew
        brew install "$@"
    elif [ "$PKG" = "apt" ]; then
        $SUDO apt-get install -y "$@"
    else
        $SUDO apk add --no-cache "$@"
    fi
}

pkg_install_cask() {
    if [ "$PKG" != "brew" ]; then
        err "Cask доступен только на macOS (brew)"
        return 1
    fi
    ensure_homebrew
    brew install --cask "$@"
}

pkg_update() {
    if [ "$PKG" = "brew" ]; then
        ensure_homebrew
        brew update
    elif [ "$PKG" = "apt" ]; then
        $SUDO apt-get update -qq
    else
        $SUDO apk update -q
    fi
}

# ── Installation functions ───────────────────────────────────────────────────
install_core_cli() {
    step "Core CLI"

    if [ "$PKG" = "brew" ]; then
        pkg_install zsh fzf ripgrep fd bat eza zoxide starship zsh-autosuggestions zsh-syntax-highlighting
    else
        local pkgs="zsh curl"
        if [ "$PKG" = "apt" ]; then
            pkgs="$pkgs zsh-autosuggestions zsh-syntax-highlighting bat fzf ripgrep fd-find"
        else
            pkgs="$pkgs zsh-autosuggestions zsh-syntax-highlighting bat fzf ripgrep fd"
        fi
        pkg_install $pkgs

        # eza
        install_github_bin "eza" "eza-community/eza" \
            'https://github.com/eza-community/eza/releases/download/v${VER}/eza_${ARCH_MU}-unknown-linux-gnu.tar.gz'

        # Starship
        if command -v starship >/dev/null 2>&1; then
            skip "starship (уже установлен)"
        else
            curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
            ok "starship установлен"
        fi

        # zoxide
        if command -v zoxide >/dev/null 2>&1; then
            skip "zoxide (уже установлен)"
        else
            curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
            ok "zoxide установлен"
        fi
    fi

    # Deploy configs
    step "Развёртывание конфигов"
    local tmpdir
    tmpdir="$(mktemp -d)"

    fetch_dotfile ".zshrc" "$tmpdir/.zshrc"
    fetch_dotfile ".bash_aliases" "$tmpdir/.bash_aliases"
    fetch_dotfile "starship.toml" "$tmpdir/starship.toml"

    deploy_file "$tmpdir/.zshrc" "$TARGET_HOME/.zshrc"
    ok ".zshrc → $TARGET_HOME/.zshrc"

    deploy_file "$tmpdir/.bash_aliases" "$TARGET_HOME/.bash_aliases"
    ok ".bash_aliases → $TARGET_HOME/.bash_aliases"

    mkdir -p "$TARGET_HOME/.config"
    deploy_file "$tmpdir/starship.toml" "$TARGET_HOME/.config/starship.toml"
    ok "starship.toml → $TARGET_HOME/.config/starship.toml"

    # Apply chosen color
    sed_inplace "s/segment0 = \"#[0-9a-fA-F]*\"/segment0 = \"$CHOSEN_COLOR\"/" \
        "$TARGET_HOME/.config/starship.toml"
    ok "Цвет Starship: $CHOSEN_COLOR"

    rm -rf "$tmpdir"

    # Fix ownership if running as root for another user
    if [ "$(id -u)" = "0" ] && [ "$TARGET_USER" != "root" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.zshrc" \
            "$TARGET_HOME/.bash_aliases" "$TARGET_HOME/.config/starship.toml"
    fi

    # Change shell
    if [ "$PKG" = "apk" ]; then
        pkg_install shadow
    fi
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [ -n "$zsh_path" ] && command -v chsh >/dev/null 2>&1; then
        # On macOS users may not exist in /etc/passwd; just try chsh.
        if [ "$UNAME_S" = "Darwin" ]; then
            chsh -s "$zsh_path" "$TARGET_USER" 2>/dev/null || true
            ok "Shell → $zsh_path для $TARGET_USER"
        else
            if [ "$(grep "^${TARGET_USER}:" /etc/passwd | cut -d: -f7)" != "$zsh_path" ]; then
                chsh -s "$zsh_path" "$TARGET_USER" 2>/dev/null || $SUDO chsh -s "$zsh_path" "$TARGET_USER"
                ok "Shell → $zsh_path для $TARGET_USER"
            else
                skip "Shell уже zsh"
            fi
        fi
    fi
}

install_system_utils() {
    step "System Utils"

    if [ "$PKG" = "brew" ]; then
        pkg_install btop ncdu jq yq mc nano duf git-delta
    else
        local pkgs="btop ncdu jq mc nano"
        pkg_install $pkgs

        # duf
        install_github_bin "duf" "muesli/duf" \
            'https://github.com/muesli/duf/releases/download/v${VER}/duf_${VER}_linux_${ARCH_DUF}.tar.gz'

        # delta
        install_github_bin "delta" "dandavison/delta" \
            'https://github.com/dandavison/delta/releases/download/${VER}/delta-${VER}-${ARCH_MU}-unknown-linux-gnu.tar.gz'

        # yq
        install_github_bin "yq" "mikefarah/yq" \
            'https://github.com/mikefarah/yq/releases/download/v${VER}/yq_linux_${ARCH_GO}'
    fi
}

install_multiplexer() {
    step "Multiplexer"

    if [ "$MUX_CHOICE" = "0" ]; then
        pkg_install tmux
        ok "tmux установлен"
    else
        if [ "$PKG" = "brew" ]; then
            pkg_install zellij
            ok "zellij установлен"
        else
            install_github_bin "zellij" "zellij-org/zellij" \
                'https://github.com/zellij-org/zellij/releases/download/v${VER}/zellij-${ARCH_MU}-unknown-linux-musl.tar.gz'
        fi
    fi
}

install_git_tools() {
    step "Git Tools"

    if [ "$PKG" = "brew" ]; then
        pkg_install lazygit
        ok "lazygit установлен"
    else
        install_github_bin "lazygit" "jesseduffield/lazygit" \
            'https://github.com/jesseduffield/lazygit/releases/download/v${VER}/lazygit_${VER}_Linux_${ARCH_MU}.tar.gz'
    fi
}

install_docker() {
    step "Docker"

    if command -v docker >/dev/null 2>&1; then
        skip "Docker (уже установлен)"
        return
    fi

    if [ "$PKG" = "brew" ]; then
        pkg_install_cask docker
        ok "Docker Desktop установлен"
        printf '\n  Запустите Docker Desktop: Applications → Docker\n'
        printf '  После старта проверьте: docker version\n\n'
        return
    elif [ "$PKG" = "apt" ]; then
        curl -fsSL https://get.docker.com | sh
        $SUDO systemctl enable --now docker
    else
        $SUDO apk add docker docker-cli-compose
        $SUDO rc-update add docker default
        $SUDO rc-service docker start
    fi

    if [ "$TARGET_USER" != "root" ]; then
        if [ "$PKG" = "apt" ]; then
            $SUDO usermod -aG docker "$TARGET_USER"
        else
            $SUDO addgroup "$TARGET_USER" docker
        fi
        ok "Пользователь $TARGET_USER добавлен в группу docker"
    fi
    ok "Docker установлен"
}

install_dockge() {
    step "Dockge"

    if ! command -v docker >/dev/null 2>&1; then
        err "Docker не установлен — пропускаю Dockge"
        return
    fi

    $SUDO mkdir -p /opt/dockge /opt/stacks
    curl -fsSL https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml \
        -o /tmp/dockge-compose.yaml
    $SUDO mv /tmp/dockge-compose.yaml /opt/dockge/compose.yaml
    (cd /opt/dockge && $SUDO docker compose up -d)
    ok "Dockge запущен на порту 5001"
}

install_tailscale() {
    step "Tailscale"

    if command -v tailscale >/dev/null 2>&1; then
        skip "Tailscale (уже установлен)"
    else
        if [ "$PKG" = "brew" ]; then
            pkg_install_cask tailscale
        elif [ "$PKG" = "apt" ]; then
            curl -fsSL https://tailscale.com/install.sh | sh
        else
            $SUDO apk add tailscale
            $SUDO rc-update add tailscale default
            $SUDO rc-service tailscale start
        fi
        ok "Tailscale установлен"
    fi

    if [ "$PKG" = "brew" ]; then
        # Try to start the app so CLI can talk to daemon
        if command -v open >/dev/null 2>&1; then
            open -a Tailscale >/dev/null 2>&1 || true
        fi
    fi

    echo ""
    echo "  Подключение к Headscale (ts.kiroru.ru)..."
    echo "  После выполнения команды откройте URL для авторизации."
    echo ""
    if ! $SUDO tailscale up --login-server https://ts.kiroru.ru; then
        err "tailscale up не удалось (возможно, нужно запустить Tailscale.app и выдать разрешения)"
        printf '  Повторите вручную: tailscale up --login-server https://ts.kiroru.ru\n'
        return
    fi
    echo ""
    printf '  Нажмите ENTER после авторизации в Headscale... '
    read -r
}

install_code_server() {
    step "code-server"

    if ! command -v code-server >/dev/null 2>&1; then
        if [ "$PKG" = "brew" ]; then
            pkg_install code-server
        else
            curl -fsSL https://code-server.dev/install.sh | sh
        fi
        ok "code-server установлен"
    else
        skip "code-server (уже установлен)"
    fi

    # Ensure config exists (first run generates it)
    local cs_config="$TARGET_HOME/.config/code-server/config.yaml"
    mkdir -p "$(dirname "$cs_config")"
    if [ ! -f "$cs_config" ]; then
        CS_PASSWORD="$(head -c 16 /dev/urandom | base64 | tr -d '/+=' | head -c 16)"
        cat > "$cs_config" <<CSEOF
bind-addr: 0.0.0.0:8080
auth: password
password: $CS_PASSWORD
cert: false
CSEOF
    else
        # Update bind-addr to 0.0.0.0
        sed_inplace 's/^bind-addr:.*/bind-addr: 0.0.0.0:8080/' "$cs_config"
        CS_PASSWORD="$(grep '^password:' "$cs_config" | awk '{print $2}')"
    fi

    if [ "$(id -u)" = "0" ] && [ "$TARGET_USER" != "root" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/code-server"
    fi

    if [ "$PKG" = "apt" ]; then
        $SUDO systemctl enable --now "code-server@${TARGET_USER}"
    elif [ "$PKG" = "brew" ]; then
        printf '\n  На macOS сервис не настраиваю автоматически.\n'
        printf '  Запуск: code-server --config "%s"\n\n' "$cs_config"
    fi
    ok "code-server слушает на 0.0.0.0:8080"
}

# ── Dry-run summary ─────────────────────────────────────────────────────────
show_dry_run() {
    printf '\033[2J\033[H'
    printf '╔════════════════════════════════════════════════╗\n'
    printf '║              DRY-RUN — план действий           ║\n'
    printf '╚════════════════════════════════════════════════╝\n\n'

    printf '  Система:     %s %s (%s)\n' "$ID" "${VERSION_ID:-}" "$ARCH_MU"
    printf '  Пользователь: %s (%s)\n' "$TARGET_USER" "$TARGET_HOME"
    printf '  Пакетный мгр: %s\n\n' "$PKG"

    if [ "${COMP_SELECTED[0]}" = "1" ]; then
        printf '  ✓ Core CLI       — zsh, starship, eza, bat, fzf, ripgrep, fd, zoxide\n'
        printf '                     Цвет Starship: %s\n' "$CHOSEN_COLOR"
        printf '                     Конфиги: .zshrc, .bash_aliases, starship.toml\n'
    fi
    if [ "${COMP_SELECTED[1]}" = "1" ]; then
        printf '  ✓ System Utils   — btop, ncdu, duf, delta, jq, yq, mc, nano\n'
    fi
    if [ "${COMP_SELECTED[2]}" = "1" ]; then
        local mux="tmux"
        [ "$MUX_CHOICE" = "1" ] && mux="zellij"
        printf '  ✓ Multiplexer    — %s\n' "$mux"
    fi
    if [ "${COMP_SELECTED[3]}" = "1" ]; then
        printf '  ✓ Git Tools      — lazygit\n'
    fi
    if [ "${COMP_SELECTED[4]}" = "1" ]; then
        printf '  ✓ Docker         — Docker Engine + Compose\n'
    fi
    if [ "${COMP_SELECTED[5]}" = "1" ]; then
        printf '  ✓ Dockge         — Docker Compose UI\n'
    fi
    if [ "${COMP_SELECTED[6]}" = "1" ]; then
        printf '  ✓ Tailscale      — VPN → ts.kiroru.ru\n'
    fi
    if [ "${COMP_SELECTED[7]}" = "1" ]; then
        printf '  ✓ code-server    — VS Code в браузере\n'
    fi

    printf '\n  Действий не выполнено (dry-run).\n\n'
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    CHOSEN_COLOR="#ff8400"

    # Non-interactive dry-run via CLI flag
    if [ "$DRY_RUN" = "1" ] && [ ! -t 0 ]; then
        show_dry_run
        exit 0
    fi

    # Step 1: Color selection (only if Core CLI will be available to select)
    # We show components first if --dry-run from CLI, otherwise color → components
    select_components

    if [ "${COMP_SELECTED[0]}" = "1" ]; then
        select_color
    fi

    # Check dry-run
    if [ "$DRY_RUN" = "1" ]; then
        show_dry_run
        exit 0
    fi

    # Update package index
    step "Обновление индекса пакетов"
    pkg_update
    ok "Индекс обновлён"

    # Install selected components
    [ "${COMP_SELECTED[0]}" = "1" ] && install_core_cli
    [ "${COMP_SELECTED[1]}" = "1" ] && install_system_utils
    [ "${COMP_SELECTED[2]}" = "1" ] && install_multiplexer
    [ "${COMP_SELECTED[3]}" = "1" ] && install_git_tools
    [ "${COMP_SELECTED[4]}" = "1" ] && install_docker
    [ "${COMP_SELECTED[5]}" = "1" ] && install_dockge
    [ "${COMP_SELECTED[6]}" = "1" ] && install_tailscale
    [ "${COMP_SELECTED[7]}" = "1" ] && install_code_server

    # Summary
    printf '\n'
    printf '╔════════════════════════════════════════════════╗\n'
    printf '║              Установка завершена!               ║\n'
    printf '╚════════════════════════════════════════════════╝\n\n'

    if [ "${COMP_SELECTED[7]}" = "1" ] && [ -n "${CS_PASSWORD:-}" ]; then
        printf '  code-server:  http://<ip>:8080\n'
        printf '  Пароль:       \033[1;32m%s\033[0m\n\n' "$CS_PASSWORD"
    fi
    if [ "${COMP_SELECTED[0]}" = "1" ]; then
        printf '  Перелогиньтесь или выполните: exec zsh\n'
    fi
    printf '\n'
}

main
