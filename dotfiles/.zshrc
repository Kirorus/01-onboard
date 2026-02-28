# User-local binaries first
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

# Node via nvm
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi

# History and shell behavior
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt AUTO_CD

bindkey -e
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select

# Plugins
BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
fi

if [ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Tool integrations
if [ -t 1 ] && command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi
if [ -t 1 ] && [ "$TERM" != "dumb" ] && [ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]; then
    source "/usr/share/doc/fzf/examples/key-bindings.zsh"
elif [ -t 1 ] && [ "$TERM" != "dumb" ] && [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]; then
    source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
fi
if [ -t 1 ] && [ "$TERM" != "dumb" ] && [ -f "/usr/share/doc/fzf/examples/completion.zsh" ]; then
    source "/usr/share/doc/fzf/examples/completion.zsh"
elif [ -t 1 ] && [ "$TERM" != "dumb" ] && [ -n "$BREW_PREFIX" ] && [ -f "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ]; then
    source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"
fi

# Aliases
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

if [ -t 1 ] && [ "$TERM" != "dumb" ] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
