# Linux Setup

Automated setup for our Kubuntu 26.04 machines (amd64 / arm64).
Requirements and decisions: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md).

## Usage

Copy this folder to the machine (no git needed), then as the desktop user (with sudo):

```sh
sh install.sh            # run everything (asks for confirmation)
sh install.sh -y         # no prompt
sh install.sh --list     # list modules
sh install.sh --only packages,dotfiles
sh install.sh --skip system-update
sh install.sh --dry-run  # print what would run
```

Copy example: `rsync -a --exclude .git Linux-Setup/ user@host:~/Linux-Setup/`

Logs go to `~/.local/state/linux-setup/`.

## Layout

```
install.sh          entry point: parses flags, checks system, runs modules in order
lib/common.sh       helpers: logging, run (dry-run aware), pkg_install, install_file, ensure_block
modules/NN-name.sh  setup steps, run in numeric order (each in a subshell)
packages/*.txt      apt packages, one per line; all files are installed
dotfiles/           copied into $HOME at the same paths (differing files backed up)
docs/               requirements and decisions
```

## Shell config

`dotfiles/.config/shell_config/` is the Linux copy of the Mac's `~/.config/shell_config`,
made neutral for a shared account. The installer appends one line to `~/.bashrc` that sources it.
Machine-specific stuff (and any secrets) goes in `~/.config/shell_config/local.sh`, created
from `local.sh.example` on first run and never shipped or overwritten.

## Adding a step

1. Create `modules/NN-name.sh` (pick NN for ordering).
2. Use the helpers from `lib/common.sh`; wrap side effects in `run` so `--dry-run` works.
3. Keep it idempotent: re-running `install.sh` must be safe.
