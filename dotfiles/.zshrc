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
if [ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Tool integrations
if [ -t 1 ] && command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi
if [ -t 1 ] && [ "$TERM" != "dumb" ] && [ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]; then
    source "/usr/share/doc/fzf/examples/key-bindings.zsh"
fi
if [ -t 1 ] && [ "$TERM" != "dumb" ] && [ -f "/usr/share/doc/fzf/examples/completion.zsh" ]; then
    source "/usr/share/doc/fzf/examples/completion.zsh"
fi

# Aliases
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza -lah --group-directories-first --git --icons=auto'
    alias la='eza -a --group-directories-first --icons=auto'
    alias lt='eza --tree --level=2 --icons=auto'
else
    alias ls='ls --color=auto'
    alias ll='ls -lah --color=auto'
    alias la='ls -A --color=auto'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --style=plain --paging=never'
elif command -v batcat >/dev/null 2>&1; then
    alias cat='batcat --style=plain --paging=never'
fi

alias grep='grep --color=auto'
alias diff='diff --color=auto'
if command -v fdfind >/dev/null 2>&1; then
    alias fd='fdfind'
fi

if [ -t 1 ] && [ "$TERM" != "dumb" ] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
