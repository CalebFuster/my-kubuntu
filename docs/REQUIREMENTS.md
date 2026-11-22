# Requirements

What `install.sh` must do, and the constraints it runs under. Update this file when a decision changes.

## 1. System constraints

| Topic | Decision |
|---|---|
| Distro | **Kubuntu 26.04 LTS** only (Ubuntu base, apt). No dnf/pacman/zypper support needed. |
| Desktop | KDE Plasma. Desktop/UI state is captured and restored with **konsave** (installed with `uv tool` into `~/.venv/konsave`; system pip is blocked by PEP 668). |
| Architectures | **amd64 and arm64.** Every third-party source must be checked for arm64; if missing, the step is skipped with a warning, never a failure. |
| Run context | Run by a normal user with sudo: `sh install.sh`. Must be re-runnable (idempotent). |
| Users | **One shared account** used by several peers. All configs must be neutral: no personal identity, tokens, or machine-specific paths. |
| Network | Most sources are public. The internal apt repo is only reachable on the **office network/VPN**: probe it first and skip with a warning if unreachable. |
| Delivery | Repo folder copied to the machine without `.git`. Nothing may depend on git metadata or exec bits. |

## 2. Shell & dotfiles

- Shell: **bash** (system default). No zsh/fish.
- Source: a **copy** of the Mac's `~/.config/shell_config` lives in `dotfiles/`. Adapt it for a shared Linux machine:
  - Keep: `xdg`, `exports`, `default_shortcuts`, `functions`, `bash_functions`, `bind_key_bash`, `manpages_colour`, prompt, history settings.
  - Drop/neutralise: Homebrew, iTerm2, Docker Desktop, macOS app paths, personal project paths (`TrackedFolders/...`, `.ws_setup`), STM32 macOS paths, `CLAUDE_CONFIG_DIR` (TBD).
  - Rename `alias ip='curl ifconfig.me'` to **`publicip`** so it doesn't shadow the Linux `ip` command.
  - **Drop `LC_ALL=C.UTF-8`** (and the `LANG=C.UTF-8` override). Let the desktop locale apply so KDE apps aren't broken.
- Git config: the `merge-msg` hook uses config-based hooks (`[hook "…"]`), which Ubuntu 26.04's git 2.53 ignores. It stays in the config and activates with a newer git. Don't use `core.hooksPath` as a workaround: it would disable repos' own hooks.
- **`local.sh` is never copied or committed.** The installer creates an empty `local.sh` template for machine-specific overrides. (The Mac's `local.sh` holds a secret token, so never copy it.)
- Also ship: vimrc, tmux, readline, git config + `ignore`, Ghostty. Remove the Mac-only lines (e.g. `rtp+=/opt/homebrew/opt/fzf`). **No nvim config** (the neovim package stays).
- **Everything follows XDG**: configs in `~/.config/<tool>/`, state/history in `~/.local/state/`, nothing new in `$HOME` (only exceptions: the one-line hook in `~/.bashrc`, `~/.ssh`, and `~/.venv/`). Legacy `~/.vimrc`, `~/.tmux.conf`, `~/.gitconfig`, `~/.inputrc` are moved aside because they would override the XDG versions.
- Git: placeholder identity **`user <user@user.com>`**, written once to `~/.config/git/local` (included from the main config). It is never overwritten, so it can be changed per machine.
- SSH: keys are **copied in manually**. The installer only creates `~/.ssh` with correct permissions and a base `config` with `Include config.d/*`.

## 3. Software

### Repos to add
| Repo | For | arm64 | Notes |
|---|---|---|---|
| deadsnakes PPA | Python versions | yes | Recent reports say it publishes 26.04 (`resolute`) packages, but this is not confirmed. Verify with `apt policy` after adding. |
| Vivaldi official apt | Vivaldi | yes | |
| Waterfox official apt | Waterfox | yes (claimed) | Waterfox 6.7 announced official deb repos for x86_64+ARM64. **Verify the URL/key and whether it's stable or beta.** The old OBS (hawkeye116477) repo is unmaintained, so don't use it. Flatpak is the fallback. |
| Docker official apt | Docker Engine | yes | |
| Microsoft apt | VS Code | yes | |
| Internal company apt | SEGGER J-Link (+ future internal pkgs) | TBD | Office/VPN only. URL + key TBD. |

### Packages
- **Base CLI:** curl, wget, git, vim, neovim, tmux, htop, unzip, zoxide, fzf, bash-completion, ca-certificates.
- **C/C++:** build-essential, pkg-config, cmake, ninja-build, gdb, clang, clang-format, clang-tidy, doxygen.
- **Python:** deadsnakes **3.12 + 3.13** (+ `-dev`; 26.04 ships 3.14 as `python3`; change in `packages/python.txt`). deadsnakes publishes 26.04 packages for amd64 and arm64 (3.7–3.13, 3.15, 3.16). Plus `uv` (official installer, as uv isn't in Ubuntu's repos). **uv must only use system (deadsnakes) Pythons**: `UV_PYTHON_PREFERENCE=only-system`, `UV_PYTHON_DOWNLOADS=never`. No pipx: `uv tool install` replaces it.
- **Venvs live in `~/.venv/<name>`** (one per tool/project, same as the Mac). This is a deliberate exception to the XDG rule. `UV_TOOL_DIR=~/.venv`, so `uv tool install konsave` → `~/.venv/konsave`, with the command linked into `~/.local/bin`. Shell helpers: `mkvenv NAME [PYVER]` and `venv NAME` (tab-completes).
- **Node:** nvm (pinned version, `PROFILE=/dev/null` so it doesn't edit `~/.bashrc`), installed into `$XDG_DATA_HOME/nvm`. Default Node: **latest LTS** (`lts/*`). npm cache/config under XDG.
- **Rust:** rustup (`--no-modify-path`, default profile) with `CARGO_HOME`/`RUSTUP_HOME` under XDG. `$CARGO_HOME/bin` is added to PATH by `exports`.
- **Docker:** Docker Engine + buildx + compose plugins from Docker's apt repo (has 26.04 amd64/arm64). `DOCKER_CONFIG` under XDG. Add the shared user to the `docker` group.
- **Serial / embedded:** picocom, minicom, screen. Add the user to the `dialout` group.
- **SEGGER J-Link:** from the internal apt repo.
- **STM32 tools:** **out of scope for now.**
- **Editors:** VS Code (extensions TBD), Neovim (no custom config), Vim.
- **Terminal:** **Ghostty** from Ubuntu universe (1.3.0 on 26.04), plus `fonts-jetbrains-mono`. Set as the KDE default terminal (`kdeglobals` → `TerminalApplication`/`TerminalService`).
- **Browsers:** Waterfox (Gecko, AI features off) and Vivaldi (Chromium). Both get **configured**, not just installed (see below).
- **KDE:** konsave (via `uv tool`) + a saved profile in the repo.
- **Others:** list TBD (e.g. more hardware/debug tools).

### Browser configuration
- Use system-wide **enterprise policies** so the settings apply to everyone on the shared account and survive profile resets.
- Waterfox: `policies.json` in the install's `distribution/` folder (exact path depends on the package). Disable AI/ML features, telemetry, sponsored content.
- Vivaldi: Chromium-style managed policy JSON. The path Vivaldi reads is **unverified** (forum reports point to `/etc/chromium/policies/managed/`). Confirm with `vivaldi://policy`.
- Policy contents (homepage, search engine, extensions, AI toggles) TBD.

## 4. System tweaks
- Remove bloat: preinstalled apps list TBD (Kubuntu defaults to review).
- Firewall, swap, unattended-upgrades, hostname, locale/timezone: specifics TBD.
- Snap Firefox: remove? (Waterfox replaces it.) TBD.

## 5. Open questions
1. SSH keys on a shared account: one shared key, or does each peer use an agent/forwarded key?
2. Internal apt repo: URL, signing-key location, suite/component, arm64 availability.
3. Full list of extra tools (picocom is in; what else?) and VS Code extensions.
4. Browser policy contents for each browser.
5. Bloat list and system-tweak specifics.
6. Should `shell_config` changes flow back to the Mac copy, or is this a fork from now on?
