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
- Also ship: vimrc, tmux, readline, git config + `ignore`, Ghostty, kitty.
- **Aligned with the lab Pis' config:** case-insensitive Tab completion, `update` alias (`apt update && upgrade -y && autoremove -y`), tmux status bar on top, tmux `&` kills a window without asking. Remove the Mac-only lines (e.g. `rtp+=/opt/homebrew/opt/fzf`). **No nvim config** (the neovim package stays).
- **Everything follows XDG**: configs in `~/.config/<tool>/`, state/history in `~/.local/state/`, nothing new in `$HOME` (only exceptions: the one-line hook in `~/.bashrc`, `~/.ssh`, and `~/.venv/`). Legacy `~/.vimrc`, `~/.tmux.conf`, `~/.gitconfig`, `~/.inputrc` are moved aside because they would override the XDG versions.
- Git: placeholder identity **`user <user@user.com>`**, written once to `~/.config/git/local` (included from the main config). It is never overwritten, so it can be changed per machine.
- **Inbound SSH (remote access to the laptop):** `openssh-server`, key-only login, no root login (drop-in `/etc/ssh/sshd_config.d/10-linux-setup.conf`). Allowed keys live in `ssh/authorized_keys` (public keys only, with a comment saying whose key it is). The installer **adds** missing keys and never removes existing ones. Password login is only disabled once at least one key is in place.
- Outgoing SSH: keys are **copied in manually**. The installer creates `~/.ssh` and `~/.ssh/config.d/` (700) and makes `Include config.d/*` the **first** line of `~/.ssh/config`. It creates the file if missing; otherwise it prepends the line and keeps a backup.
- **RDP:** KDE's built-in **KRdp** server (`krdp`, 6.6.4 on 26.04) on port 3389, started with the Plasma session. Login uses the account's normal password (`SystemUserEnabled`). The TLS certificate is **generated on each machine** (`~/.local/share/krdpserver/`) and never copied.
- **Not adopted from the laptop** (personal): keyboard-clock sync service, VIA, keyboard layouts, power settings, VS Code settings, Remmina.

## 3. Software

### Repos to add
| Repo | For | arm64 | Notes |
|---|---|---|---|
| deadsnakes PPA | Python versions | yes | Verified: publishes 26.04 (`resolute`) packages. |
| Vivaldi official apt | Vivaldi | yes | Added **only for the first install**: the `vivaldi-stable` package then replaces the repo file with its own and keeps it current (daily cron), so the installer leaves it alone afterwards. |
| Waterfox official apt | Waterfox | yes | Official BrowserWorks repo on openSUSE OBS, `isv:BrowserWorks/xUbuntu_26.04` (flat repo). Stable since 6.7 (6.7.8 at time of writing). Not the old unmaintained hawkeye116477 repo. |
| Docker official apt | Docker Engine | yes | |
| Microsoft apt | VS Code | yes | The `code` package leaves our repo file alone. |
| Sublime HQ apt | Sublime Text | yes | Official repo `download.sublimetext.com`, `apt/stable/` (flat repo). |
| Quantica apt (`http://10.13.10.6/q3d-ppa-pi`, key `q3d-ppa-pi.asc`) | SEGGER J-Link | ? | From `fw_scripts/raspberry_pi/setup_pi.sh`. Office network/VPN only, plain HTTP. Built for the Raspberry Pis: **unverified** whether it has a `resolute` suite or amd64 builds. Only added when it serves `jlink` for this machine's release+arch, so it can't break `apt update`. |

### Packages
- **Base CLI:** curl, wget, git, vim, neovim, tmux, htop, unzip, zoxide, fzf, bash-completion, ca-certificates, net-tools.
- **C/C++:** build-essential, pkg-config, cmake, ninja-build, gdb, clang, clang-format, clang-tidy, doxygen.
- **Python:** deadsnakes **3.12 + 3.13** (+ `-dev`; 26.04 ships 3.14 as `python3`; change in `packages/python.txt`). deadsnakes publishes 26.04 packages for amd64 and arm64 (3.7–3.13, 3.15, 3.16). Plus `uv` (official installer, as uv isn't in Ubuntu's repos). **uv must only use system (deadsnakes) Pythons**: `UV_PYTHON_PREFERENCE=only-system`, `UV_PYTHON_DOWNLOADS=never`. No pipx: `uv tool install` replaces it.
- **Venvs live in `~/.venv/<name>`** (one per tool/project, same as the Mac). This is a deliberate exception to the XDG rule. `UV_TOOL_DIR=~/.venv`, so `uv tool install konsave` → `~/.venv/konsave`, with the command linked into `~/.local/bin`. Shell helpers: `mkvenv NAME [PYVER]` and `venv NAME` (tab-completes).
- **Node:** nvm (pinned version, `PROFILE=/dev/null` so it doesn't edit `~/.bashrc`), installed into `$XDG_DATA_HOME/nvm`. Default Node: **latest LTS** (`lts/*`). npm cache/config under XDG.
- **Rust:** rustup (`--no-modify-path`, default profile) with `CARGO_HOME`/`RUSTUP_HOME` under XDG. `$CARGO_HOME/bin` is added to PATH by `exports`.
- **Docker:** Docker Engine + buildx + compose plugins from Docker's apt repo (has 26.04 amd64/arm64). `DOCKER_CONFIG` under XDG. Add the shared user to the `docker` group.
- **Serial / embedded:** picocom, minicom, screen. Add the user to the `dialout` group.
- **SEGGER J-Link:** from the Quantica repo when it serves `jlink` for this Ubuntu release + arch. Otherwise it's skipped with a warning. **Opt-in** fallback: `JLINK_FROM_SEGGER=1 sh install.sh --only jlink` downloads the official `.deb` from segger.com, accepting SEGGER's license (same as `install_jlink_pi.sh`); `JLINK_VERSION=Vxxx` pins a version.
- **Team lab tools** (copied from `fw_scripts`, same as on the lab Pis): `serial_logger.sh`, `psu_direct.py`, `psu_remote.py` (Korad KA3010P PSU) in `~/.local/bin`, plus `python3-serial`. `PICOMAP` exported for `picocom $PICOMAP`.
- **STM32 tools:** **out of scope for now.**
- **Editors:** VS Code (`code`, Microsoft repo; no settings shipped; extensions TBD), Sublime Text (`sublime-text`, Sublime HQ repo; no settings shipped), Neovim (no custom config), Vim.
- **Terminal:** **Ghostty** from Ubuntu universe (1.3.0 on 26.04), plus `fonts-jetbrains-mono`. Set as the KDE default terminal (`kdeglobals` → `TerminalApplication`/`TerminalService`). Config merges the laptop's (no decoration, 0.80 opacity, copy-on-select) and the Mac's (window size, blur). Drop-down toggle on **Alt+Shift+A** via `~/.local/bin/toggle-ghostty.sh` (KWin script); its `.desktop` entries are rendered per machine because `Exec=` can't expand `$HOME`.
- **Browsers:** Waterfox (Gecko, AI features off) and Vivaldi (Chromium). Both get **configured**, not just installed (see below).
- **KDE:** see *KDE desktop* below.
- **Extras:** kitty (second terminal, laptop config with Catppuccin-Mocha theme, **not** autostarted), lazygit (apt).
- **OpenLogi** (Logitech HID++ mouse settings, [AprilNEA/OpenLogi](https://github.com/AprilNEA/OpenLogi)): not in any apt repo, so the pinned release `.deb` (**v0.9.0**, stable) is installed after a SHA-256 check. The agent starts with the graphical session.
- **herdr** (terminal multiplexer for AI coding agents, [ogulcancelik/herdr](https://github.com/ogulcancelik/herdr)): not in any apt repo, so the pinned release binary (**v0.9.5**) goes to `~/.local/bin` after a SHA-256 check.
- **Others:** list TBD (e.g. more hardware/debug tools).

### KDE desktop
- Look: **WhiteSur-dark** (global theme `WhiteSurLiquid-dark`, Plasma theme, Aurorae decoration, Kvantum `kvantum-dark`, WhiteSur-dark icons). Panels use **stock KDE widgets only**; the third-party plasmoids in the laptop export are unused and not installed.
- **Themes come from upstream at pinned versions** (never in git): WhiteSur-kde @ commit `cf4df59` (the last tag, 2024-11-18, predates the Liquid variant) and WhiteSur-icon-theme @ `2026-09-10`. Installed per user under `~/.local/share` and `~/.config/Kvantum`. Downloads are cached in `~/.cache/linux-setup`.
- **Settings:** konsave profile kept **unpacked** in `kde/profile/` (~300 KB, diffable), trimmed from the laptop's `Sequoia.knsv`. The installer zips, imports and applies it. Left out: monitor layout (`kwinoutputconfig.json`), region (`plasma-localerc`), KDE migration state (`kconf_updaterc`), theme files, Ghostty/tmux (from dotfiles). A personal home-folder wallpaper path was removed.
- **Cursor:** `Apple-cursors` (manual download, unknown license) is **not committed**. It's extracted from a local `*.knsv` placed next to `install.sh` (or `KNSV=/path`). Without one, KDE's default cursor is used.
- **Login screen:** SDDM theme WhiteSur-dark (system-wide, from the same WhiteSur-kde commit), **autologin disabled**, via `/etc/sddm.conf.d/zz-linux-setup.conf`. That file overrides System Settings' SDDM page, so edit it instead.
- `*.knsv` files are gitignored: the laptop export is 1.1 GB (mostly ~2.8 GB of unused icon themes). Keep only `cursors.knsv` (1.5 MB, just Apple-cursors) next to `install.sh` and copy it along with the folder.

### Browser configuration
- Use system-wide **enterprise policies** so the settings apply to everyone on the shared account and survive profile resets. Files live in `browsers/`; `modules/88-browsers.sh` installs them.
- **Waterfox** → `/etc/waterfox/policies/policies.json`. **Verified loaded** (headless `about:policies`). Baseline: **all AI blocked and locked** (`AIControls.Default=blocked`, which also blocks on-device translation, plus `GenerativeAI` off), Visual Search off, telemetry and studies off, sponsored tiles/stories/suggestions off, Mozilla promos and onboarding off. (`DisablePocket` was dropped: Waterfox ignores it, and `FirefoxHome` already hides Pocket.)
- **Vivaldi** → `/etc/vivaldi/policies/managed/linux-setup.json`. The path is confirmed (hard-coded in the Vivaldi binary); the forum guess `/etc/chromium/...` was wrong. Loading is **not yet verified** (headless Vivaldi doesn't render internal pages): check `vivaldi://policy` on a real machine. Baseline is minimal, since Vivaldi ships no generative AI: no on-device AI model download, no metrics, no promotions.
- **Waterfox look: WhiteSur (macOS-style)**, the same theme as the laptop's Firefox (which konsave never captured). Theme files come from WhiteSur-gtk-theme @ `2026-09-10` (`other/firefox`, default variant) plus the laptop's `userChrome.css` (`browsers/waterfox-userChrome.css`: hides window buttons when maximized). They're built into `~/.local/share/linux-setup/waterfox-chrome`; every `~/.waterfox/*default*` profile gets `chrome` linked there, plus the prefs WhiteSur's installer sets in `user.js`. If no profile exists yet, Waterfox is run once headless to create it. (`~/.waterfox` is Waterfox's own path; it can't be moved to XDG.)
- **Vivaldi look: native window frame** (`vivaldi.windows.use_native_decoration`), so KDE draws its WhiteSur-dark title bar with macOS-style buttons. Vivaldi can't use `userChrome.css` themes. It ignores `vivaldi.*` keys in `initial_preferences`, so the installer creates the profile (headless first run, retried without Chromium's sandbox where that can't start) and sets the key in `~/.config/vivaldi/Default/Preferences` while Vivaldi is closed. Re-running re-applies it.
- Both are done by `modules/89-browser-theme.sh`.
- **Default browser: Vivaldi**: links/HTML via `mimeapps.list`, KDE's `BrowserApplication`, and `x-www-browser`. The taskbar's pinned Firefox was replaced with `preferred://browser`.
- Homepage, search engine, extensions: **left as is** (no extra policies).

## 4. System tweaks
- **Remove bloat** (`modules/90-debloat.sh`, editable lists): Firefox and Thunderbird snaps plus their transitional `.deb`s, Konsole (Ghostty replaces it), games (kmahjongg, kmines, kpat, ksudoku), neochat, plasma-welcome, usb-creator-kde, khelpcenter, and the media players elisa and haruna (so audio/video files have no default player). Verified on the laptop with `apt-get -s purge` that only these 11 packages go and `kubuntu-desktop` stays. Snapd is kept. An apt pin (`/etc/apt/preferences.d/no-snap-transitional`) stops Ubuntu's firefox/thunderbird from coming back; both are only *Recommends* of `kubuntu-desktop`, so the metapackage stays.
- **Firewall: none** (ufw stays off, Kubuntu default). SSH is key-only; RDP uses the account password and is reachable on any network the laptop joins.
- **Swap: zram + existing swapfile.** `systemd-zram-generator` makes a compressed swap in RAM (half of RAM, zstd, priority 100), used before the installer's disk swapfile (kept as overflow).
- **Automatic updates: security only** (Ubuntu default, enforced via `/etc/apt/apt.conf.d/20auto-upgrades`). Everything else is updated with the `update` alias or Discover.
- **Hostname: asked at the start of the install**, with the current name as default (Enter keeps it). `-y` keeps the current name; `HOSTNAME_NEW=name` sets it without a prompt. Validated (a-z, 0-9, `-`), and `/etc/hosts` is kept in sync.
- **Locale, keyboard, timezone: left as chosen in the Kubuntu installer** (peers in Berlin and Barcelona differ). Only NTP time sync is turned on.

## 5. Open questions
1. SSH keys on a shared account: one shared key, or does each peer use an agent/forwarded key?
2. Quantica apt repo: does it serve a `resolute` suite and amd64? (Check on the office network: `curl http://10.13.10.6/q3d-ppa-pi/dists/`.)
3. More tools to add over time (VS Code extensions and browser policies are intentionally left as is for now).
4. Should `shell_config` changes flow back to the Mac copy, or is this a fork from now on?

## 6. Still to verify on a real machine
- J-Link from the Quantica repo (needs office network).
- Vivaldi policies load (`vivaldi://policy`).
- Waterfox WhiteSur look and Vivaldi native frame (headless can't render the browser UI).
- KDE look after login (run `konsave -s before-linux-setup` first on a machine you care about).
- RDP connection (port 3389) and OpenLogi with a real mouse.
- Snap removal of Firefox/Thunderbird; zram active (`swapon --show`); hostname change.
- amd64: Node via nvm (the emulator here can't unpack Node's tarball).
