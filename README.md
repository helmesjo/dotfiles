# dotfiles

## Setup

```sh
./setup.sh
```

Detects the current OS, installs packages, symlinks configs, and runs
OS-specific configuration scripts.

### Windows, brand-new machine

`setup.sh` needs a genuine MSYS2 UCRT64 shell to run in, which a stock
Windows install doesn't have yet.

1. Get this repo onto disk with a real `git clone` (e.g. install Git for
   Windows first, then `git clone https://github.com/helmesjo/dotfiles`) -
   a zip download won't work, since `configure.sh` relies on `git ls-files`.
2. From PowerShell, inside the checkout:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
   ```
   Installs MSYS2 if it isn't already present, then runs `./setup.sh` inside
   a real UCRT64 shell.

From then on, use the "MSYS2 UCRT64" shell shortcut and run `./setup.sh`
directly, same as macOS/Linux.

---

## How it works

### OS detection

`scripts/get-os.sh` identifies the current OS and returns a key such as
`linux-arch`, `macos`, or `windows`. This key is used throughout to select
the right configs and scripts. The OS is identified from `$OSTYPE` (set by
the shell). When running inside WSL, `$WSL_DISTRO_NAME` (set by the WSL
kernel for all WSL processes) is used to distinguish WSL from a native Linux
host so that WSL-specific scripts apply.

### Config symlinking

`scripts/configure.sh` iterates over `configs/<os>/` and creates a symlink
in `$HOME` for each tracked file or directory. Only files tracked by git are
linked - untracked files are skipped. If something already exists at the
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
- `scripts/windows/require-ucrt64.sh` refuses to continue outside a genuine
  MSYS2 UCRT64 shell (checked via `uname -s`, since `$MSYSTEM` can be
  overridden by `.env.local`) rather than limping along in the wrong
  subsystem, and points to `bootstrap.ps1` or the UCRT64 shortcut instead.
  `setup.sh`, `scripts/windows/install.sh`, and `scripts/configure.sh` each
  source it independently, since any of them can be run standalone rather
  than only via `setup.sh`.

---

## Structure

```bash
setup.sh                  # entry point
bootstrap.ps1             # Windows only: gets a fresh machine to a UCRT64 shell, then runs setup.sh

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
  windows/
    require-ucrt64.sh     # guard: refuse to run outside genuine MSYS2 UCRT64
```

### Adding a new config

Drop the file or directory into `configs/<os>/` and `git add` it. The next
run of `setup.sh` (or `scripts/configure.sh` directly) will symlink it.

### Platform-shared configs

Files shared across platforms live under the most complete platform (currently
`linux-arch`) and are symlinked or referenced from other platforms where needed.
