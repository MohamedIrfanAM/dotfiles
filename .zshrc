#general env and PATH
export PATH="$PATH:$(go env GOPATH)/bin"
export EDITOR="nvim"
export VISUAL="nvim"

. "$HOME/.local/bin/env"

#history 
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

#shell behaviour
setopt NOBEEP
setopt NUMERIC_GLOB_SORT  # sort file10 after file9, not after file1

#alias
alias ls='eza --icons=auto'
alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias vim='nvim'
alias cat='\bat'
alias bat='\cat'
alias docker='podman'

#bat
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
[ ! -x /usr/bin/bat ] && [ -x /usr/bin/cat ] && alias cat='bat'

# zsh completion memu
autoload -Uz compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)	
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
compdef eza=ls

# zoxide
eval "$(zoxide init zsh)"

# Plugin setup
source /Users/irfan.m/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
source /Users/irfan.m/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
source /Users/irfan.m/.config/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh
source /Users/irfan.m/.config/zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# vim mode plugin config
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLOCK
ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none
zvm_after_init() {
  bindkey '^[f' forward-word
  bindkey '^[b' backward-word
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey '^R' fzf-history-widget
  bindkey '^[^?' backward-kill-word
  bindkey '^U' backward-kill-line
}

# zsh-autosuggestions
bindkey '^ ' autosuggest-accept

#FZF
export FZF_DEFAULT_OPTS='--height 90% --layout=reverse --border=rounded --inline-info --margin 1% --padding 1% --color="bg:#282c34,bg+:#3e4451,fg:#abb2bf,fg+:#ffffff,hl:#61afef,hl+:#61afef,info:#98c379,prompt:#e5c07b,pointer:#c678dd,marker:#e06c75,spinner:#56b6c2,header:#5c6370,border:#5c6370" --preview "bat --style=numbers --color=always --line-range :500 {}"'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
eval "$(fzf --zsh)"

# Starship
eval "$(starship init zsh)"
