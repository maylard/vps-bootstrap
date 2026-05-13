#!/usr/bin/env bash
# Terminal beautifier for Linux VPSes and macOS:
#   starship (pastel-powerline preset) + eza/bat/fzf/zoxide + fortune/cowsay/lolcat
# Idempotent. Safe to re-run. User-local install where possible.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/maylard/vps-bootstrap/main/bootstrap.sh | bash
#
# macOS note: Homebrew must be installed first (https://brew.sh). On Linux, sudo
# is used when available; otherwise everything goes into ~/.local/bin.

set -euo pipefail

# ---------- configuration ----------
RAW_BASE="${VPS_BOOTSTRAP_RAW_BASE:-https://raw.githubusercontent.com/maylard/vps-bootstrap/main}"

# Pinned versions for Linux GitHub-release tarball fallbacks (bump deliberately).
EZA_VERSION="v0.21.7"
ZOXIDE_VERSION="0.9.8"
BAT_VERSION="0.25.0"
FZF_VERSION="0.62.0"

BEGIN_MARK="# >>> vps-bootstrap >>>"
END_MARK="# <<< vps-bootstrap <<<"

# ---------- logging ----------
log()  { printf '\033[1;32m[bootstrap]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Portable in-place trim of trailing blank lines (works in bash 3.2+ on macOS).
trim_trailing_blanks() {
  local file="$1" tmp line n i
  local lines=()
  tmp="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do lines+=("$line"); done < "$file"
  n=${#lines[@]}
  while [ "$n" -gt 0 ] && [ -z "${lines[$((n-1))]:-}" ]; do n=$((n-1)); done
  : > "$tmp"
  for (( i=0; i<n; i++ )); do printf '%s\n' "${lines[i]}" >> "$tmp"; done
  mv "$tmp" "$file"
}

# ---------- env detection ----------
detect_env() {
  case "$(uname -s)" in
    Linux)  OS_KIND="linux" ;;
    Darwin) OS_KIND="macos" ;;
    *)      die "unsupported OS: $(uname -s)" ;;
  esac

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64)  ARCH_GH="x86_64";  ARCH_DEB="amd64" ;;
    aarch64|arm64) ARCH_GH="aarch64"; ARCH_DEB="arm64" ;;
    *)             ARCH_GH="$ARCH";   ARCH_DEB="$ARCH" ;;
  esac

  IS_ROOT=0
  [ "${EUID:-$(id -u)}" -eq 0 ] && IS_ROOT=1

  if [ "$OS_KIND" = "linux" ]; then
    OS_ID="unknown"; OS_VERSION_ID="unknown"
    if [ -r /etc/os-release ]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      OS_ID="${ID:-unknown}"
      OS_VERSION_ID="${VERSION_ID:-unknown}"
    fi
    HAVE_SUDO=0
    if [ "$IS_ROOT" -eq 1 ]; then
      HAVE_SUDO=1
    elif have sudo && sudo -n true 2>/dev/null; then
      HAVE_SUDO=1
    fi
    APT_OK=0
    if have apt-get && [ "$HAVE_SUDO" -eq 1 ]; then APT_OK=1; fi
    log "linux/${OS_ID}-${OS_VERSION_ID} arch=$ARCH sudo=$HAVE_SUDO apt=$APT_OK"
  else
    have brew || die "Homebrew not found. Install via https://brew.sh and re-run."
    BREW_PREFIX="$(brew --prefix)"
    log "macos arch=$ARCH brew=$BREW_PREFIX"
  fi

  mkdir -p "$HOME/.local/bin" "$HOME/.config"
}

# ---------- linux: apt + tarball fallbacks ----------
sudo_if_needed() {
  if [ "$IS_ROOT" -eq 1 ]; then "$@"; else sudo "$@"; fi
}

apt_install() {
  [ "${APT_OK:-0}" -eq 1 ] || return 1
  sudo_if_needed env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

install_starship_linux() {
  if have starship; then
    log "starship already installed: $(starship --version | head -1)"
    return
  fi
  log "installing starship into ~/.local/bin"
  curl -sSf https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

install_eza_linux() {
  if have eza; then return; fi
  if apt_install eza 2>/dev/null; then return; fi
  warn "apt eza unavailable; falling back to GitHub release ${EZA_VERSION}"
  local url tmp
  url="https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_${ARCH_GH}-unknown-linux-gnu.tar.gz"
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" | tar -xz -C "$tmp"; then
    install -m 0755 "$tmp/eza" "$HOME/.local/bin/eza"
  else
    warn "eza install failed; skipping"
  fi
  rm -rf "$tmp"
}

install_bat_linux() {
  if have bat || have batcat; then return; fi
  if apt_install bat 2>/dev/null; then return; fi
  warn "apt bat unavailable; falling back to GitHub release ${BAT_VERSION}"
  local url tmp
  url="https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-${ARCH_GH}-unknown-linux-gnu.tar.gz"
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" | tar -xz -C "$tmp" --strip-components=1; then
    install -m 0755 "$tmp/bat" "$HOME/.local/bin/bat"
  else
    warn "bat install failed; skipping"
  fi
  rm -rf "$tmp"
}

install_fzf_linux() {
  if have fzf; then return; fi
  if apt_install fzf 2>/dev/null; then return; fi
  warn "apt fzf unavailable; falling back to GitHub release ${FZF_VERSION}"
  local url tmp
  url="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${ARCH_DEB}.tar.gz"
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" | tar -xz -C "$tmp"; then
    install -m 0755 "$tmp/fzf" "$HOME/.local/bin/fzf"
  else
    warn "fzf install failed; skipping"
  fi
  rm -rf "$tmp"
}

install_zoxide_linux() {
  if have zoxide; then return; fi
  if apt_install zoxide 2>/dev/null; then return; fi
  warn "apt zoxide unavailable; falling back to GitHub release ${ZOXIDE_VERSION}"
  local url tmp
  url="https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-${ARCH_GH}-unknown-linux-musl.tar.gz"
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" | tar -xz -C "$tmp"; then
    install -m 0755 "$tmp/zoxide" "$HOME/.local/bin/zoxide"
  else
    warn "zoxide install failed; skipping"
  fi
  rm -rf "$tmp"
}

install_motd_linux() {
  if have fortune && have cowsay && have lolcat; then return; fi
  if apt_install fortune-mod fortunes cowsay lolcat 2>/dev/null; then return; fi
  warn "fortune/cowsay/lolcat not installable; skipping MOTD packages"
}

install_all_linux() {
  install_starship_linux
  install_eza_linux
  install_bat_linux
  install_fzf_linux
  install_zoxide_linux
  install_motd_linux
}

# ---------- macos: homebrew, one shot ----------
install_all_macos() {
  log "brew install: starship eza bat fzf zoxide cowsay fortune lolcat"
  brew install starship eza bat fzf zoxide cowsay fortune lolcat
}

# ---------- starship.toml (shared) ----------
write_starship_toml() {
  local dest="$HOME/.config/starship.toml"
  local tmp
  tmp="$(mktemp)"
  if ! curl -fsSL "$RAW_BASE/starship.toml" -o "$tmp"; then
    warn "could not fetch starship.toml from $RAW_BASE; skipping"
    rm -f "$tmp"
    return
  fi
  if [ -f "$dest" ] && ! cmp -s "$dest" "$tmp"; then
    local bak
    bak="${dest}.bak.$(date +%s)"
    cp -a "$dest" "$bak"
    log "existing starship.toml differs; backed up to $bak"
  fi
  mv "$tmp" "$dest"
  log "wrote $dest"
}

# ---------- rc-file management ----------
strip_managed_block() {
  local rc="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b)==1 { skip=1 }
    !skip            { print }
    index($0, e)==1 { skip=0; next }
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
  trim_trailing_blanks "$rc"
}

update_bashrc() {
  local rc="$HOME/.bashrc"
  [ -f "$rc" ] || touch "$rc"
  strip_managed_block "$rc"
  cat >> "$rc" <<'BLOCK'

# >>> vps-bootstrap >>> (managed; do not edit between markers)
export PATH="$HOME/.local/bin:$PATH"
command -v starship >/dev/null && eval "$(starship init bash)"
command -v zoxide   >/dev/null && eval "$(zoxide init bash)"
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/bash-completion/completions/fzf ]   && . /usr/share/bash-completion/completions/fzf

# eza
if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first --git'
  alias la='eza -a  --icons --group-directories-first'
fi

# bat: Debian/Ubuntu ships it as `batcat`; alias rather than shadow `cat`
if   command -v bat    >/dev/null; then :
elif command -v batcat >/dev/null; then alias bat='batcat'
fi

# navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
myip() { curl -fsSL https://ifconfig.me && echo; }

# human-readable sizes
alias df='df -h'
alias du='du -h'
alias free='free -h'

# apt one-shot update
alias update='sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y'

# random cow + fortune + lolcat MOTD on interactive shells
if [ -n "$PS1" ] && command -v fortune >/dev/null && command -v cowsay >/dev/null; then
  _cow="$(cowsay -l 2>/dev/null | tail -n +2 | tr ' \t' '\n\n' | grep -v '^$' \
          | awk 'BEGIN{srand()} {a[NR]=$0} END{if(NR>0) print a[int(rand()*NR)+1]}')"
  if command -v lolcat >/dev/null; then
    fortune | cowsay -f "${_cow:-default}" | lolcat
  else
    fortune | cowsay -f "${_cow:-default}"
  fi
  unset _cow
fi
# <<< vps-bootstrap <<<
BLOCK
  log "updated $rc"
}

update_zshrc() {
  local rc="$HOME/.zshrc"
  [ -f "$rc" ] || touch "$rc"
  strip_managed_block "$rc"
  cat >> "$rc" <<'BLOCK'

# >>> vps-bootstrap >>> (managed; do not edit between markers)
# Homebrew on PATH (Apple Silicon then Intel)
[ -d /opt/homebrew/bin ] && export PATH="/opt/homebrew/bin:$PATH"
[ -d /usr/local/bin ]    && export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide   >/dev/null && eval "$(zoxide init zsh)"
command -v fzf      >/dev/null && eval "$(fzf --zsh)"

# eza
if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first --git'
  alias la='eza -a  --icons --group-directories-first'
fi

# navigation
# Use `function` keyword form for mkcd/myip so zsh skips alias expansion at
# parse time (oh-my-zsh and similar frameworks often define a `myip` alias).
unalias mkcd myip 2>/dev/null
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
function mkcd { mkdir -p -- "$1" && cd -- "$1"; }
function myip { curl -fsSL https://ifconfig.me && echo; }

# human-readable sizes (no `free` on macOS; use `vm_stat` if needed)
alias df='df -h'
alias du='du -h'

# brew one-shot update
alias update='brew update && brew upgrade && brew cleanup'

# random cow + fortune + lolcat MOTD on interactive shells
if [ -n "$PS1" ] && command -v fortune >/dev/null && command -v cowsay >/dev/null; then
  _cow="$(cowsay -l 2>/dev/null | tail -n +2 | tr ' \t' '\n\n' | grep -v '^$' \
          | awk 'BEGIN{srand()} {a[NR]=$0} END{if(NR>0) print a[int(rand()*NR)+1]}')"
  if command -v lolcat >/dev/null; then
    fortune | cowsay -f "${_cow:-default}" | lolcat
  else
    fortune | cowsay -f "${_cow:-default}"
  fi
  unset _cow
fi
# <<< vps-bootstrap <<<
BLOCK
  log "updated $rc"
}

# ---------- main ----------
main() {
  have curl || die "curl is required"
  detect_env
  if [ "$OS_KIND" = "macos" ]; then
    install_all_macos
    write_starship_toml
    update_zshrc
    log ""
    log "Done. Open a fresh terminal tab (or 'exec zsh') to see the new prompt."
  else
    install_all_linux
    write_starship_toml
    update_bashrc
    log ""
    log "Done. Open a fresh Warp tab and SSH in again to see the new prompt."
  fi
  log "If glyphs render as tofu: set a Nerd Font in your terminal's appearance settings."
}

main "$@"
