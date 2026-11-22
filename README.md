# Linux Setup

Automated setup for my Linux instances.

## Usage

Copy this folder to the machine (no git needed), then:

```sh
sh install.sh            # run everything (asks for confirmation)
sh install.sh -y         # no prompt
sh install.sh --list     # list modules
sh install.sh --only packages,dotfiles
sh install.sh --skip system-update
sh install.sh --dry-run  # print what would run
```

Copy example: `scp -r Linux-Setup user@host:~/` or `rsync -a --exclude .git Linux-Setup/ user@host:~/Linux-Setup/`

Logs go to `~/.local/state/linux-setup/`.

## Layout

```
install.sh          entry point: parses flags, detects distro, runs modules in order
lib/common.sh       helpers: logging, run (dry-run aware), pkg_install, link_file
modules/NN-name.sh  setup steps, run in numeric order (each in a subshell)
packages/common.txt packages with the same name everywhere
packages/<mgr>.txt  distro-specific packages (apt, dnf, pacman, zypper)
dotfiles/           mirrored into $HOME as symlinks (existing files backed up)
```

## Adding a step

1. Create `modules/NN-name.sh` (pick NN for ordering).
2. Use the helpers from `lib/common.sh`; wrap side effects in `run` so `--dry-run` works.
3. Keep it idempotent: re-running `install.sh` should be safe.

Supported package managers: apt, dnf, pacman, zypper.
