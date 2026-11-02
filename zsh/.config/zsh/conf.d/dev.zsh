# Entorno de desarrollo: toolchain vía mise (config en el paquete stow `mise/`).
# Se activa solo si mise está instalado. En una máquina nueva:
#   curl https://mise.run | sh && stow mise && mise install

[[ -x ~/.local/bin/mise ]] || (( $+commands[mise] )) || return 0

eval "$(mise activate zsh)"
source ~/.config/zsh/cloud.zsh

[[ -d ~/.dotnet/tools ]]  && path+=(~/.dotnet/tools)
[[ -d ~/.opencode/bin ]]  && path=(~/.opencode/bin $path)
