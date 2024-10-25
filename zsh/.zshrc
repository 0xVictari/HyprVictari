# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zap-zsh/zap-prompt"
plug "zsh-users/zsh-syntax-highlighting"
export POSH_THEME="$HOME/.config/oh-my-posh/config.toml"
plug "wintermi/zsh-oh-my-posh"

# Load and initialise completion system
autoload -Uz compinit
compinit

# Powerlevel10k theme path
#source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# In case a command is not found, try to find the package that has it
#function command_not_found_handler {
#    local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' reset='\e[0m'
#    printf 'zsh: command not found: %s\n' "$1"
#    local entries=( ${(f)"$(/usr/bin/pacman -F --machinereadable -- "/usr/bin/$1")"} )
#    if (( ${#entries[@]} )) ; then
#        printf "${bright}$1${reset} may be found in the following packages:\n"
#        local pkg
#        for entry in "${entries[@]}" ; do
#            local fields=( ${(0)entry} )
#            if [[ "$pkg" != "${fields[2]}" ]]; then
#                printf "${purple}%s/${bright}%s ${green}%s${reset}\n" "${fields[1]}" "${fields[2]}" "${fields[3]}"
#            fi
#            printf '    /%s\n' "${fields[4]}"
#            pkg="${fields[2]}"
#        done
#    fi
#    return 127
#}

# Detect AUR wrapper
if pacman -Qi yay &>/dev/null; then
   aurhelper="yay"
elif pacman -Qi paru &>/dev/null; then
   aurhelper="paru"
fi

function in {
    local -a inPkg=("$@")
    local -a arch=()
    local -a aur=()

    for pkg in "${inPkg[@]}"; do
        if pacman -Si "${pkg}" &>/dev/null; then
            arch+=("${pkg}")
        else
            aur+=("${pkg}")
        fi
    done

    if [[ ${#arch[@]} -gt 0 ]]; then
        sudo pacman -S "${arch[@]}"
    fi

    if [[ ${#aur[@]} -gt 0 ]]; then
        ${aurhelper} -S "${aur[@]}"
    fi
}

# Helpful aliases
alias c='clear' # clear terminal
alias l='eza -lh --icons=auto' # long list
#alias ls='eza -1 --icons=auto' # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhD --icons=auto' # long list dirs
alias lt='eza --icons=auto --tree' # list folder as tree
alias un='$aurhelper -Rns' # uninstall package
alias up='$aurhelper -Syu' # update system/package/aur
alias pl='$aurhelper -Qs' # list installed package
alias pa='$aurhelper -Ss' # list available package
alias pc='$aurhelper -Sc' # remove unused cache
alias po='$aurhelper -Qtdq | $aurhelper -Rns -' # remove unused packages, also try > $aurhelper -Qqd | $aurhelper -Rsu --print -
alias vc='code' # gui code editor

# Directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# Always mkdir a path (this doesn't inhibit functionality to make a single dir)
alias mkdir='mkdir -p'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
#[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Define aliases.
alias tree='tree -a -I .git'

# Add flags to existing aliases.
alias ls="${aliases[eza]:-eza} -A --icons=auto"
alias vim=nvim
# Helpful aliases
alias  c='clear' # clear terminal

#Disable Zap before enabling oh-my-posh or starship
#eval "$(starship init zsh)"
#eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/config.toml)"
fastfetch
