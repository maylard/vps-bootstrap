# vps-bootstrap

A one-shot installer that makes any fresh Linux VPS look as nice as your favourite Warp SSH session: [starship](https://starship.rs) with the pastel-powerline preset, plus `eza`, `bat`, `fzf`, and `zoxide`. Bash only. Idempotent. Safe to re-run.

## Install

On a new VPS, with your normal user account (sudo is used only when available, otherwise everything goes into `~/.local/bin`):

```sh
curl -fsSL https://raw.githubusercontent.com/<you>/vps-bootstrap/main/bootstrap.sh | bash
```

Then **open a fresh Warp tab and SSH in again** — the new prompt only shows up in new shells.

## What it does

1. Installs `starship` into `~/.local/bin` via its official installer.
2. Installs `eza`, `bat`, `fzf`, `zoxide` — via `apt` when available, otherwise GitHub-release tarballs into `~/.local/bin`. Individual failures are warnings, not fatal.
3. Drops the committed `starship.toml` into `~/.config/starship.toml`. If you already have one and it differs, the old file is copied to `starship.toml.bak.<epoch>` first.
4. Appends a managed block to `~/.bashrc` between sentinel markers (`# >>> vps-bootstrap >>>` ... `# <<< vps-bootstrap <<<`) that:
   - inits starship and zoxide,
   - sources fzf's bash key-bindings and completion,
   - aliases `ls`/`ll`/`la` to `eza` (with Nerd Font icons + git status),
   - aliases `bat` to `batcat` on Debian/Ubuntu (does **not** shadow `cat`).

Re-running the script replaces the managed block in place — no duplicates.

## Customising the prompt

The `starship.toml` shipped here is the pastel-powerline preset (`starship preset pastel-powerline -o starship.toml`). To tweak it, edit the file in this repo, commit, then re-run the curl pipe on each VPS.

## The font

The Nerd Font glyphs (chevrons, folder icon, branch icon) are rendered by **Warp on your Mac**, not the server. If you see tofu boxes:

**Warp → Settings → Appearance → Text → Font** — pick a Nerd Font (e.g. `JetBrainsMono Nerd Font`, `FiraCode Nerd Font`).

## Files

- `bootstrap.sh` — the installer.
- `starship.toml` — the pastel-powerline preset, committed so you can tweak.

## Sharp edges

- Warp sets `TERM=xterm-256color` over SSH and renders glyphs from the client font; do not export `TERM` server-side.
- Ubuntu 20.04 lacks `eza` and `zoxide` in apt; 22.04 lacks `eza`. The tarball fallback covers both. Versions are pinned at the top of `bootstrap.sh` — bump deliberately.
- The bashrc block aliases `bat='batcat'` rather than shadowing `cat`, to keep scripts and heredocs safe.
- `chsh` is **not** called; your login shell stays as whatever it was.
