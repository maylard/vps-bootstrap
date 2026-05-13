#!/usr/bin/env bash
# VPS terminal beautifier: starship + eza/bat/fzf/zoxide for bash.
# Idempotent. Safe to re-run. User-local install where possible.
#
# Usage on a fresh VPS:
#   curl -fsSL https://raw.githubusercontent.com/<you>/vps-bootstrap/main/bootstrap.sh | bash
#
# Override the source (e.g. testing a fork or branch):
#   VPS_BOOTSTRAP_RAW_BASE=https://raw.githubusercontent.com/<you>/<repo>/<branch> \
#     bash bootstrap.sh

set -euo pipefail

# ---------- configuration ----------
RAW_BASE="${VPS_BOOTSTRAP_RAW_BASE:-https://raw.githubusercontent.com/maylard/vps-bootstrap/main}"

# Pinned versions for GitHub-release tarball fallbacks (bump deliberately).
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

# ---------- env detection ----------
detect_env() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION_ID="${VERSION_ID:-unknown}"
  else
    OS_ID="unknown"
    OS_VERSION_ID="unknown"
  fi

  IS_ROOT=0
  [ "${EUID:-$(id -u)}" -eq 0 ] && IS_ROOT=1

  HAVE_SUDO=0
  if [ "$IS_ROOT" -eq 1 ]; then
    HAVE_SUDO=1
  elif command -v sudo >/dev/null && sudo -n true 2>/dev/null; then
    HAVE_SUDO=1
  fi

  APT_OK=0
  if command -v apt-get >/dev/null && [ "$HAVE_SUDO" -eq 1 ]; then
    APT_OK=1
  fi

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64)  ARCH_GH="x86_64";  ARCH_DEB="amd64" ;;
    aarch64|arm64) ARCH_GH="aarch64"; ARCH_DEB="arm64" ;;
    *)             ARCH_GH="$ARCH";   ARCH_DEB="$ARCH" ;;
  esac

  mkdir -p "$HOME/.local/bin" "$HOME/.config"

  log "os=$OS_ID/$OS_VERSION_ID arch=$ARCH root=$IS_ROOT sudo=$HAVE_SUDO apt=$APT_OK"
}

# ---------- helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }

sudo_if_needed() {
  if [ "$IS_ROOT" -eq 1 ]; then "$@"; else sudo "$@"; fi
}

apt_install() {
  [ "$APT_OK" -eq 1 ] || return 1
  sudo_if_needed env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

# ---------- starship ----------
install_starship() {
  if have starship; then
    log "starship already installed: $(starship --version | head -1)"
    return
  fi
  log "installing starship into ~/.local/bin"
  curl -sSf https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

# ---------- per-tool installers (apt first, GitHub-release fallback) ----------
install_eza() {
  if have eza; then log "eza already installed"; return; fi
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

install_bat() {
  if have bat || have batcat; then log "bat already installed"; return; fi
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

install_fzf() {
  if have fzf; then log "fzf already installed"; return; fi
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

install_zoxide() {
  if have zoxide; then log "zoxide already installed"; return; fi
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

install_cli_tools() {
  install_eza
  install_bat
  install_fzf
  install_zoxide
}

# ---------- starship.toml ----------
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

# ---------- .bashrc managed block ----------
update_bashrc() {
  local rc="$HOME/.bashrc"
  [ -f "$rc" ] || touch "$rc"

  # Strip any existing managed block (idempotent re-run).
  local tmp
  tmp="$(mktemp)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b)==1 { skip=1 }
    !skip            { print }
    index($0, e)==1 { skip=0; next }
  ' "$rc" > "$tmp"

  # Trim trailing blank lines so re-runs do not accumulate whitespace.
  sed -i -e :a -e '/^$/{$d;N;ba' -e '}' "$tmp" 2>/dev/null || true

  mv "$tmp" "$rc"

  cat >> "$rc" <<'BLOCK'

# >>> vps-bootstrap >>> (managed; do not edit between markers)
export PATH="$HOME/.local/bin:$PATH"
command -v starship >/dev/null && eval "$(starship init bash)"
command -v zoxide   >/dev/null && eval "$(zoxide init bash)"
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
[ -f /usr/share/bash-completion/completions/fzf ]   && . /usr/share/bash-completion/completions/fzf
if command -v eza >/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first --git'
  alias la='eza -a  --icons --group-directories-first'
fi
if   command -v bat    >/dev/null; then :
elif command -v batcat >/dev/null; then alias bat='batcat'
fi
# <<< vps-bootstrap <<<
BLOCK
  log "updated $rc"
}

# ---------- main ----------
main() {
  have curl || die "curl is required"
  detect_env
  install_starship
  install_cli_tools
  write_starship_toml
  update_bashrc

  log ""
  log "Done. Open a fresh Warp tab and SSH in again to see the new prompt."
  log "If glyphs render as tofu: set a Nerd Font in Warp -> Settings -> Appearance -> Text."
}

main "$@"
