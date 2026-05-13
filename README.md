# vps-bootstrap

A one-shot installer for a nicer terminal: [starship](https://starship.rs) with the pastel-powerline preset, plus `eza`, `bat`, `fzf`, `zoxide`, and `fortune | cowsay | lolcat` MOTD. Works on **Linux VPSes (bash)** and **macOS (zsh)**. Idempotent. Safe to re-run.

## Install

### Linux

On a new VPS with your normal user account (sudo is used only when available, otherwise everything goes into `~/.local/bin`):

```sh
curl -fsSL https://raw.githubusercontent.com/maylard/vps-bootstrap/main/bootstrap.sh | bash
```

Then **open a fresh Warp tab and SSH in again** — the new prompt only shows up in new shells.

### macOS

Install [Homebrew](https://brew.sh) first, then:

```sh
curl -fsSL https://raw.githubusercontent.com/maylard/vps-bootstrap/main/bootstrap.sh | bash
```

Same one-liner. It detects Darwin, installs everything via `brew`, and writes to `~/.zshrc`. Then `exec zsh` (or open a new tab).

## What it does

1. Installs `starship`:
   - Linux: official installer into `~/.local/bin`
   - macOS: `brew install starship`
2. Installs `eza`, `bat`, `fzf`, `zoxide`, `cowsay`, `fortune`, `lolcat`:
   - Linux: apt when available, GitHub-release tarballs as fallback. Individual failures are warnings, not fatal.
   - macOS: `brew install ...` in one shot.
3. Drops the committed `starship.toml` into `~/.config/starship.toml`. If you already have one and it differs, the old file is copied to `starship.toml.bak.<epoch>` first.
4. Appends a managed block between sentinel markers (`# >>> vps-bootstrap >>>` ... `# <<< vps-bootstrap <<<`) to the appropriate rc file:
   - Linux: `~/.bashrc` (bash init lines, batcat alias, `free -h`, `update='sudo apt …'`)
   - macOS: `~/.zshrc` (zsh init lines, `fzf --zsh`, `update='brew …'`, no `batcat`/`free`)

Re-running replaces the managed block in place — no duplicates. The managed block also includes:

- aliases `ls`/`ll`/`la` to `eza` (with Nerd Font icons + git status),
- navigation shortcuts (`..`, `...`, `....`, `mkcd`, `myip`),
- `df` / `du` with `-h` for human-readable sizes,
- a random-cow MOTD: `fortune | cowsay -f <random> | lolcat` on every new interactive shell.

## Customising the prompt icon

The clock in the prompt uses 🦫 (U+1F9AB BEAVER) as a stand-in for "capybara" since Unicode doesn't have a capybara emoji yet. Edit `starship.toml` line 162 (`format = '[ 🦫 $time ]($style)'`) to swap it for anything: an ASCII rodent like `(•ᴥ•)`, the classic `♥`, a Nerd Font glyph, etc.

## Customising the prompt

The `starship.toml` shipped here is the pastel-powerline preset (`starship preset pastel-powerline -o starship.toml`). To tweak it, edit the file in this repo, commit, then re-run the curl pipe on each host.

## The font

Nerd Font glyphs (chevrons, folder icon, branch icon) are rendered by **your terminal app on the client side**, not the server. If glyphs show as tofu boxes:

- **Warp:** Settings → Appearance → Text → Font → pick a Nerd Font (e.g. `JetBrainsMono Nerd Font`, `FiraCode Nerd Font`).
- **Apple Terminal / iTerm2:** same idea in their respective font settings.

## Files

- `bootstrap.sh` — the installer.
- `starship.toml` — the pastel-powerline preset, committed so you can tweak.

## Sharp edges

- Warp sets `TERM=xterm-256color` over SSH and renders glyphs from the client font; do not export `TERM` server-side.
- Ubuntu 20.04 lacks `eza` and `zoxide` in apt; 22.04 lacks `eza`. The tarball fallback covers both. Versions are pinned at the top of `bootstrap.sh` — bump deliberately.
- The bashrc block aliases `bat='batcat'` rather than shadowing `cat`, to keep scripts and heredocs safe.
- `chsh` is **not** called; your login shell stays as whatever it was (typically bash on Linux, zsh on macOS).
- The MOTD picks a random cow via `cowsay -l` (cross-platform), not `ls /usr/share/cowsay/cows/` (Linux-only path).
- `shuf` isn't on macOS by default, so the random pick uses an `awk` one-liner for portability.
