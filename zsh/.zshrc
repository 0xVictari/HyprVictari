# ~/.zshrc — compartido entre Desktop (Arch/Hyprland) y laptop (Mint/dwm).
# Lo específico de cada entorno vive en ~/.config/zsh/conf.d/*.zsh y cada
# módulo se activa solo si encuentra sus herramientas (sin depender del hostname).
# Lo que no se versiona va en ~/.zshrc.local.

# --- Plugins (Zap) ---
# Instalar en una maquina nueva (sin el install.zsh oficial, que reescribe este archivo):
#   git clone --depth 1 -b release-v1 https://github.com/zap-zsh/zap ~/.local/share/zap
if [[ -f ${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh ]]; then
    source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
    plug "zsh-users/zsh-autosuggestions"
    plug "zap-zsh/supercharge"
    plug "zsh-users/zsh-syntax-highlighting"
fi

# --- PATH ---
typeset -U path   # sin duplicados
path=(~/.local/bin $path)
[[ -d ~/.npm-global/bin ]] && path=(~/.npm-global/bin $path)
[[ -d ~/.opencode/bin ]]   && path=(~/.opencode/bin $path)
[[ -d ~/.dotnet/tools ]]   && path+=(~/.dotnet/tools)

# --- Completion (supercharge ya corre compinit; esto cubre el caso sin Zap) ---
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi

# --- Teclado (modo emacs; solo lo que no viene por defecto) ---
bindkey -e
bindkey '^[[H'    beginning-of-line     # Home
bindkey '^[[F'    end-of-line           # End
bindkey '^[[3~'   delete-char           # Supr
bindkey '^[[3;5~' kill-word             # Ctrl+Supr
bindkey '^H'      backward-kill-word    # Ctrl+Backspace
bindkey '^[[1;5D' backward-word         # Ctrl+←
bindkey '^[[1;5C' forward-word          # Ctrl+→
bindkey '^[[1;3D' backward-word         # Alt+←
bindkey '^[[1;3C' forward-word          # Alt+→
bindkey '^[p'     history-search-backward
bindkey '^[n'     history-search-forward

# --- Aliases ---
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias mkdir='mkdir -p'
alias tree='tree -a -I .git'
alias vim=nvim
[[ -x ~/doomwads/doom-infinite.sh ]] && alias doom-infinite=~/doomwads/doom-infinite.sh

if (( $+commands[eza] )); then
  alias ls='eza -A --icons=auto'
  alias l='eza -lh --icons=auto'
  alias ll='eza -lha --icons=auto --sort=name --group-directories-first'
  alias ld='eza -lhD --icons=auto'
  alias lt='eza --icons=auto --tree'
fi

# --- Arch (solo si hay pacman) ---
if (( $+commands[pacman] )); then
  if (( $+commands[yay] )); then aurhelper=yay
  elif (( $+commands[paru] )); then aurhelper=paru
  fi

  # in <pkgs...>: instala de los repos con pacman y el resto del AUR
  in() {
    local -a arch=() aur=()
    local pkg
    for pkg in "$@"; do
      if pacman -Si "$pkg" &>/dev/null; then arch+=("$pkg"); else aur+=("$pkg"); fi
    done
    (( ${#arch} )) && sudo pacman -S "${arch[@]}"
    (( ${#aur} ))  && $aurhelper -S "${aur[@]}"
  }

  alias un='$aurhelper -Rns'                    # desinstalar
  alias up='$aurhelper -Syu'                    # actualizar todo
  alias pl='$aurhelper -Qs'                     # buscar instalados
  alias pa='$aurhelper -Ss'                     # buscar disponibles
  alias pc='$aurhelper -Sc'                     # limpiar cache
  alias po='$aurhelper -Qtdq | $aurhelper -Rns -'  # quitar huérfanos
fi

# --- Módulos ---
for f in ~/.config/zsh/conf.d/*.zsh(N); do source "$f"; done
unset f
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# --- Prompt y extras ---
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[oh-my-posh] )) && eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/config.toml)"
(( $+commands[fastfetch] )) && fastfetch
