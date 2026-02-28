# Modern CLI aliases and integrations for bash.

if command -v eza >/dev/null 2>&1; then
    # eza colors (Catppuccin-ish, readable). Can be overridden via $EZA_COLORS.
    : "${EZA_COLORS:=di=38;5;110:ln=38;5;73:ex=38;5;114:pi=38;5;215:so=38;5;203:bd=38;5;215;1:cd=38;5;214;1:da=38;5;245:tm=38;5;245:uu=38;5;180:un=38;5;180:gu=38;5;150:gn=38;5;150}"
    export EZA_COLORS
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza -lah --group-directories-first --git --icons=auto'
    alias la='eza -a --group-directories-first --icons=auto'
    alias lt='eza --tree --level=2 --icons=auto'
else
    if [ "$(uname -s)" = "Darwin" ]; then
        alias ls='ls -G'
        alias ll='ls -lahG'
        alias la='ls -AG'
    else
        alias ls='ls --color=auto'
        alias ll='ls -lah --color=auto'
        alias la='ls -A --color=auto'
    fi
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --style=plain --paging=never'
elif command -v batcat >/dev/null 2>&1; then
    alias cat='batcat --style=plain --paging=never'
fi

if command grep --help 2>&1 | command grep -q -- '--color'; then
    alias grep='grep --color=auto'
fi
if command diff --help 2>&1 | command grep -q -- '--color'; then
    alias diff='diff --color=auto'
fi
if command -v fdfind >/dev/null 2>&1; then
    alias fd='fdfind'
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if [ -f "/usr/share/doc/fzf/examples/key-bindings.bash" ]; then
    . "/usr/share/doc/fzf/examples/key-bindings.bash"
fi
if [ -f "/usr/share/doc/fzf/examples/completion.bash" ]; then
    . "/usr/share/doc/fzf/examples/completion.bash"
fi

# Homebrew fzf integration (macOS)
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
    if [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.bash" ]; then
        . "$BREW_PREFIX/opt/fzf/shell/key-bindings.bash"
    fi
    if [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/opt/fzf/shell/completion.bash" ]; then
        . "$BREW_PREFIX/opt/fzf/shell/completion.bash"
    fi
fi
