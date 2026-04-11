# dotfiles

## Setup

```sh
./setup.sh
```

Detects the current OS, installs packages, symlinks configs, and runs
OS-specific configuration scripts.

---

## How it works

### OS detection

`scripts/get-os.sh` identifies the current OS and returns a key such as
`linux-arch`, `macos`, or `windows`. This key is used throughout to select
the right configs and scripts.

### Config symlinking

`scripts/configure.sh` iterates over `configs/<os>/` and creates a symlink
in `$HOME` for each tracked file or directory. Only files tracked by git are
linked — untracked files are skipped. If something already exists at the
target path, it is backed up with a timestamp suffix before being replaced.

### Install and configure scripts

`scripts/<os>/install.sh` installs packages for that OS.

After installation, `scripts/configure.sh` runs every `configure-*.sh`
script found in `scripts/<os>/`. These handle OS-specific setup that can't
be expressed as a config file (registry entries, service enablement,
symlinks outside `$HOME`, etc.).

On Windows, there is additional ceremony involved. The shell is zsh running
inside MSYS2, which provides a Unix-like layer over Win32. Several things
need to be massaged into place to make it behave consistently:

- `~/.config` is symlinked to `AppData/Roaming` since Windows doesn't
  follow XDG conventions, so config files land where apps expect them.
- Symlinks require `MSYS=winsymlinks:nativestrict` to produce real Windows
  native symlinks rather than MSYS copies or junctions.
- Some setup can't go through dotfiles at all and is applied directly:
  registry imports via `reg.exe`, persistent env vars via `setx`, and
  autostart/Start Menu shortcuts copied into the appropriate Windows
  directories.

---

## Structure

```bash
configs/
  <os>/           # files here get symlinked to $HOME
    .zshrc
    .bashrc
    .config/
      ...

scripts/
  get-os.sh               # OS detection
  configure.sh            # symlinks configs/, runs configure-* scripts
  <os>/
    install.sh            # package installation
    configure-*.sh        # post-install configuration
```

### Adding a new config

Drop the file or directory into `configs/<os>/` and `git add` it. The next
run of `setup.sh` (or `scripts/configure.sh` directly) will symlink it.

### Platform-shared configs

Files shared across platforms live under the most complete platform (currently
`linux-arch`) and are symlinked or referenced from other platforms where needed.
