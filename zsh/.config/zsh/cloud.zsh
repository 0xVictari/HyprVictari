# Aliases y helpers de AWS / Terraform / Terragrunt (tools vía mise).
# Lo carga conf.d/dev.zsh solo donde mise está instalado.

# --- Terraform ---
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfs='terraform state list'
alias tfv='terraform validate'
alias tff='terraform fmt -recursive'

# --- Terragrunt ---
alias tg='terragrunt'
alias tgi='terragrunt init'
alias tgp='terragrunt plan'
alias tga='terragrunt apply'
alias tgo='terragrunt output'
alias tgra='terragrunt run --all'
alias tgclean='find . -type d -name .terragrunt-cache -prune -exec rm -rf {} +'

# Plan a archivo + resumen en árbol. Uso: tfplan [args de plan]  /  tgplan [args]
_plan_summary() {
  local bin=$1; shift
  local out=${TMPDIR:-/tmp}/plan-$$.tfplan
  $bin plan -out="$out" "$@" || return
  $bin show -json "$out" | tf-summarize -tree
  echo "\nplan guardado en $out  (apply: $bin apply $out | TUI: tftui)"
}
tfplan() { _plan_summary terraform "$@"; }
tgplan() { _plan_summary terragrunt "$@"; }

# --- AWS ---
# Perfiles leídos de ~/.aws/config (más rápido que `aws configure list-profiles`)
_aws_profiles() {
  sed -nE 's/^\[(profile )?([^] ]+)\]$/\2/p' "${AWS_CONFIG_FILE:-$HOME/.aws/config}" 2>/dev/null
}

# Como `asp` de oh-my-zsh: asp <perfil> [login]  |  asp (sin args) elige con fzf
asp() {
  local p=${1:-$(_aws_profiles | fzf --height 40% --prompt 'AWS profile> ')}
  [[ -n $p ]] || return
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  export AWS_PROFILE=$p AWS_DEFAULT_PROFILE=$p
  [[ $2 == login ]] && aws sso login --profile "$p"
}
_asp() { (( CURRENT == 2 )) && compadd -- $(_aws_profiles) || compadd login; }
(( $+functions[compdef] )) && compdef _asp asp
alias asu='unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN'
alias awslogin='aws sso login'
alias awswho='aws sts get-caller-identity'
asr() { export AWS_REGION=${1:?region} AWS_DEFAULT_REGION=$1; }

# granted: `assume` debe correr con source para exportar variables
command -v assume >/dev/null && alias assume='source assume'
