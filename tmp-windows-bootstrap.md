# Windows bootstrap: notes for testing/fixing on a real machine

This was designed and written on macOS, with no Windows machine available
to actually run it on. Everything below is either verified by reading the
existing repo code, or is a best-effort inference that needs confirming on
real Windows. If something in this flow breaks, start here.

## What changed and why

- `scripts/windows/install.sh` used to winget-install MSYS2 mid-script, then
  immediately call bare `pacman`. That fails when the whole script is run
  from Git Bash: MSYS2 gets installed to disk, but the currently running
  Git Bash process never had `pacman` on `PATH` and doesn't become MSYS2
  just because MSYS2 exists on disk now.
- `configs/windows/.env.local` unconditionally forces `MSYSTEM=UCRT64`
  regardless of what shell is actually running, so `$MSYSTEM` alone can't
  be trusted to detect the problem.
- Fix: `scripts/windows/require-ucrt64.sh` checks `uname -s` instead (the
  compiled-in identity of that shell's own `uname.exe`, not overridable by
  `.env.local`) and refuses to continue if it doesn't start with `UCRT64`.
  It's sourced independently by `setup.sh`, `scripts/windows/install.sh`,
  and `scripts/configure.sh`, since any of those can run standalone.
- `bootstrap.ps1` (repo root) is the new brand-new-machine entry point: run
  it from PowerShell, from inside an already-cloned checkout. It installs
  MSYS2 via winget if missing, then launches a genuine UCRT64 shell
  (`msys2_shell.cmd -ucrt64 ... -shell bash -lc "cd '<repo>' && exec ./setup.sh"`)
  to run `./setup.sh`.
- `scripts/windows/install.sh` also gained `mingw-w64-ucrt-x86_64-gcc` in
  `pacmanpkgs`, since `configure-conpty.sh` requires `gcc` but nothing
  installed a compiler before.

## Things that need verifying on real Windows

1. **`msys2_shell.cmd -shell bash -lc "<command>"` flag grammar.** Every
   existing use of this launcher elsewhere in the repo (Alacritty config,
   Start Menu shortcut) is an interactive login shell with no inline
   command (`-shell zsh --login`, nothing after). Running one command
   non-interactively and exiting is a new usage shape for this repo. If it
   drops into an interactive shell instead of running `setup.sh` and
   exiting, or if quoting around `$posix`/`$cmd` in `bootstrap.ps1` gets
   mangled passing through `cmd.exe` (msys2_shell.cmd is a .bat/.cmd file),
   that's the first thing to check.
2. **`Start-Process -FilePath "$Msys2Root\msys2_shell.cmd" -ArgumentList $argList -NoNewWindow -Wait`**
   - confirm this actually blocks until `setup.sh` finishes and correctly
   propagates its exit code, and that `-NoNewWindow` attaches to the
   current console rather than silently detaching.
3. **`uname -s` output format.** The guard checks for a `UCRT64` prefix,
   inferred from this repo's existing `MSYSTEM_CHOST`/`MSYSTEM_CARCH`
   conventions and MSYS2's documented subsystem names (MSYS, MINGW32,
   MINGW64, UCRT64, CLANG64, CLANGARM64) - not confirmed against real
   `uname -s` output on a genuine UCRT64 shell. If the guard refuses to
   pass even in a real UCRT64 shell, print `uname -s` there and adjust the
   prefix check in `scripts/windows/require-ucrt64.sh`.
4. **Package IDs**: `winget install --id MSYS2.MSYS2`, `--id Git.Git`, and
   pacman package `mingw-w64-ucrt-x86_64-gcc` - confirm these are still the
   correct current identifiers.
5. **`Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'`**
   in `bootstrap.ps1` (the winget-missing fallback) - untested. If it
   throws or doesn't register `winget`, that's expected to be caught and
   fall through to the hard error pointing at `https://aka.ms/getwinget`;
   confirm that fallback message is what actually shows up.

## Once this is confirmed working

Fold any fixes back into `bootstrap.ps1` / `scripts/windows/require-ucrt64.sh`
directly, then delete this file (`git rm tmp-windows-bootstrap.md`) - it's
scratch context for getting this working, not permanent documentation.
