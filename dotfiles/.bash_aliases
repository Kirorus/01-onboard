# Modern CLI aliases and integrations for bash.

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

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if [ -f "/usr/share/doc/fzf/examples/key-bindings.bash" ]; then
    . "/usr/share/doc/fzf/examples/key-bindings.bash"
fi
if [ -f "/usr/share/doc/fzf/examples/completion.bash" ]; then
    . "/usr/share/doc/fzf/examples/completion.bash"
fi
