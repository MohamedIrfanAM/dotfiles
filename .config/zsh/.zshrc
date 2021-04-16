# Lines configured by zsh-newuser-install
HISTFILE=~/.cache/zsh/history
HISTSIZE=1000 SAVEHIST=1000
unsetopt beep

zstyle :compinstall filename '/home/irfan/.config/zsh/.zshrc'
autoload -Uz compinit
compinit
# autoload -U compinit
# Basic auto/tab complete:
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.

### SETTING THE STARSHIP PROMPT ###
eval "$(starship init zsh)"
### RANDOM COLOR SCRIPT ###
# Get this script from my GitLab: gitlab.com/dwt1/shell-color-scripts
# Or install it from the Arch User Repository: shell-color-scripts
# colorscript random
# autoload -U promptinit; promptinit
# prompt spaceship

# # vi mode
# bindkey -v
# export KEYTIMEOUT=1

# Use vim keys in tab complete menu:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

# # Change cursor shape for different vi modes.
# function zle-keymap-select {
#   if [[ ${KEYMAP} == vicmd ]] ||
#      [[ $1 = 'block' ]]; then
#     echo -ne '\e[1 q'
#   elif [[ ${KEYMAP} == main ]] ||
#        [[ ${KEYMAP} == viins ]] ||
#        [[ ${KEYMAP} = '' ]] ||
#        [[ $1 = 'beam' ]]; then
#     echo -ne '\e[5 q'
#   fi
# }
# zle -N zle-keymap-select
# zle-line-init() {
#     zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
#     echo -ne "\e[5 q"
# }
# zle -N zle-line-init
# echo -ne '\e[5 q' # Use beam shape cursor on startup.
# preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

bindkey -s '^o' 'ranger\n'
# /usr/share/fzf/completion.zsh
# /usr/share/fzf/key-bindings.zsh

# # Edit line in vim with ctrl-e:
# autoload edit-command-line; zle -N edit-command-line
# bindkey '^e' edit-command-line


# If not running interactively, don't do anything
[[ $- != *i* ]] && return

### PATH
if [ -d "$HOME/.bin" ] ;
  then PATH="$HOME/.bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ;
  then PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/Applications" ] ;
  then PATH="$HOME/Applications:$PATH"
fi

### CHANGE TITLE OF TERMINALS
case ${TERM} in
  xterm*|rxvt*|Eterm*|aterm|kterm|gnome*|alacritty|st|konsole*|kitty)
    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\007"'
        ;;
  screen*)
    PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\033\\"'
    ;;
esac

function sort
{
mv /run/media/irfan/Programming/cp/Codeforces* /run/media/irfan/Programming/cp/codeforces
mv /run/media/irfan/Programming/cp/CodeChef*  /run/media/irfan/Programming/cp/codeshef
mv /run/media/irfan/Programming/cp/At* /run/media/irfan/Programming/cp/atcoder
mv /run/media/irfan/Programming/cp/Ha* /run/media/irfan/Programming/cp/hackerrank
rm /run/media/irfan/Programming/cp/*.exe
clear
}
alias c="sort ; cd /run/media/irfan/Programming/cp/" 

### Function extract for common file formats ###
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

function extract {
 if [ -z "$1" ]; then
    # display usage if no parameters given
    echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
    echo "       extract <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"
 else
    for n in "$@"
    do
      if [ -f "$n" ] ; then
          case "${n%,}" in
            *.cbt|*.tar.bz2|*.tar.gz|*.tar.xz|*.tbz2|*.tgz|*.txz|*.tar)
                         tar xvf "$n"       ;;
            *.lzma)      unlzma ./"$n"      ;;
            *.bz2)       bunzip2 ./"$n"     ;;
            *.cbr|*.rar)       unrar x -ad ./"$n" ;;
            *.gz)        gunzip ./"$n"      ;;
            *.cbz|*.epub|*.zip)       unzip ./"$n"       ;;
            *.z)         uncompress ./"$n"  ;;
            *.7z|*.arj|*.cab|*.cb7|*.chm|*.deb|*.dmg|*.iso|*.lzh|*.msi|*.pkg|*.rpm|*.udf|*.wim|*.xar)
                         7z x ./"$n"        ;;
            *.xz)        unxz ./"$n"        ;;
            *.exe)       cabextract ./"$n"  ;;
            *.cpio)      cpio -id < ./"$n"  ;;
            *.cba|*.ace)      unace x ./"$n"      ;;
            *)
                         echo "extract: '$n' - unknown archive method"
                         return 1
                         ;;
          esac
      else
          echo "'$n' - file does not exist"
          return 1
      fi
    done
fi
}

IFS=$SAVEIFS

function mkcd {
  last=$(eval "echo \$$#")
  if [ ! -n "$last" ]; then
    echo "Enter a directory name"
  elif [ -d $last ]; then
    echo "\`$last' already exists"
  else
    mkdir $@ && cd $last
  fi
}

cdls() {
        local dir="$1"
        local dir="${dir:=$HOME}"
        if [[ -d "$dir" ]]; then
                cd "$dir" >/dev/null; exa -al --color=always --group-directories-first 
        else
                echo "bash: cdls: $dir: Directory not found"
        fi
}

# Aliases 

#Vim
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias icat="kitty +kitten icat"
alias cat='bat'

# Replace some more things with better alternatives
[ ! -x /usr/bin/bat ] && [ -x /usr/bin/cat ] && alias cat='bat'
### "bat" as manpager
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
#get the error messages from journalctl

alias jctl="journalctl -p 3 -xb"

# Get fastest mirrors 
alias mirror="sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist" 
alias mirrord="sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist" 
alias mirrors="sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist" 
alias mirrora="sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist" 

# Common use alias aup="pamac upgrade --aur"
alias grubup="sudo update-grub"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias upd='sudo reflector --latest 5 --age 2 --fastest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && cat /etc/pacman.d/mirrorlist && sudo pacman -Syu && fish_update_completions && sudo updatedb'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias hw='hwinfo --short'                                   # Hardware Info
alias big="expac -H M '%m\t%n' | sort -h | nl"              # Sort installed packages according to size in MB (expac must be installed)
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'			# List amount of -git packages

#Recent Installed Packages
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

#Cleanup orphaned packages
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'

# Replace yay with paru
[ ! -x /usr/bin/yay ] && [ -x /usr/bin/paru ] && alias yay='paru'

alias tb='nc termbin.com 9999'
alias paru="paru --bottomup"

# confirm before overwriting something
alias cp="cp -i"
alias mv='mv -i'
alias rm='rm -i'


# Changing "ls" to "exa"
alias ls='exa -l --color=always --group-directories-first' # my preferred listing
alias la='exa -al --color=always --group-directories-first'  # all files and dirs
alias ll='exa -l --color=always --group-directories-first'  # long format
alias lt='exa -aT --color=always --group-directories-first' # tree listing
alias l.='exa -a | egrep "^\."'

# Get fastest mirrors 
alias mirror="sudo reflector -f 30 -l 30 --number 10 --verbose --save /etc/pacman.d/mirrorlist" 
alias mirrord="sudo reflector --latest 50 --number 20 --sort delay --save /etc/pacman.d/mirrorlist" 
alias mirrors="sudo reflector --latest 50 --number 20 --sort score --save /etc/pacman.d/mirrorlist" 
alias mirrora="sudo reflector --latest 50 --number 20 --sort age --save /etc/pacman.d/mirrorlist" 

# Colorize grep output (good for log files)
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'


# # configure node version manager
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export NVM_DIR=~/.nvm
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use # This loads nvm
alias node='unalias node ; unalias npm ; nvm use default ; node $@'
alias npm='unalias node ; unalias npm ; nvm use default ; npm $@'
# [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use

### BASH INSULTER ###
if [ -f /etc/bash.command-not-found ]; then
    . /etc/bash.command-not-found
fi

# zsh-vi-mode
source /usr/share/zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh
ZVM_VI_EDITOR=nvim
function zvm_after_init() {
  zvm_bindkey viins 'jk' zvm_exit_insert_mode
  zvm_bindkey viins 'kj' zvm_exit_insert_mode
}

# zsh-autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
bindkey '^ ' autosuggest-accept

# zsh-syntax-highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
ZSH_HIGHLIGHT_STYLES[command]='fg=#004EFF'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#E10600'
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=green'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#004EFF'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#66FF00'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#66FF00'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#004EFF'

# For sorting all contest directory 
/home/irfan/.config/zsh/sort.sh
