#!/usr/bin/env bash
# bdep-sync.test.sh: isolated regression suite for ../bdep-sync.sh
#
# Drives the real bdep/bpkg/b toolchain end-to-end against throwaway git
# repos + bpkg configurations built fresh per scenario (mktemp sandboxes,
# torn down after each scenario). No mocks.
#
# Usage:
#   bash bdep-sync.test.sh              # run every scenario
#   bash bdep-sync.test.sh S16          # run scenarios whose id/description
#                                       # matches this substring
#
# requires: bdep, bpkg, b, git, a C++ compiler on PATH (set BDEP_SYNC_TEST_CXX
# to override the default of g++), bash

_self=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
_hook_dir=$(cd "$_self/.." && pwd)
_hook_sync="$_hook_dir/bdep-sync.sh"
_hook_checkout="$_hook_dir/post-checkout"

_cxx=${BDEP_SYNC_TEST_CXX:-g++}
_filter="${1:-}"

clr_ok=$'\e[1;32m' clr_err=$'\e[1;31m' clr_warn=$'\e[1;33m' clr_def=$'\e[1;0m'

_pass=0
_fail=0
_failed_names=()

_root_tmp=""
_template=""

# ---------------------------------------------------------------------------
# generic helpers
# ---------------------------------------------------------------------------

_strip_ansi() { sed -E 's/\x1b\[[0-9;]*m//g'; }

_ok() {
  _pass=$((_pass + 1))
  printf '%s PASS %s%s\n' "$clr_ok" "$clr_def" "$1"
}

_bad() {
  _fail=$((_fail + 1))
  _failed_names+=("$1")
  printf '%s FAIL %s%s\n' "$clr_err" "$clr_def" "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/       | /' >&2
  fi
}

# assert helper: $1=condition (0/1) $2=description $3=detail-on-failure
_check() {
  if [[ "$1" -eq 0 ]]; then _ok "$2"; else _bad "$2" "${3:-}"; fi
}

_setup_suite() {
  _root_tmp=$(mktemp -d "${TMPDIR:-/tmp}/bdep-sync-test.XXXXXX")
  _template="$_root_tmp/template"
  mkdir -p "$_template"
  if ! (
    cd "$_template" &&
      bdep new -t empty --vcs none prj >/dev/null &&
      cd prj &&
      bdep new --package -l c++ -t lib,binless libcore >/dev/null &&
      bdep new --package -l c++ -t exe my-app >/dev/null &&
      bdep new --package -l c++ -t lib,binless libcore-ext >/dev/null
  ) 2>"$_root_tmp/setup.err"; then
    echo "FATAL: template project setup failed:" >&2
    cat "$_root_tmp/setup.err" >&2
    exit 1
  fi
  # Wire a real dependency so a "removed pkg has a kept dependent" scenario is
  # possible: libcore-ext depends on libcore.
  sed -i 's/^#depends: libhello .*/depends: libcore/' "$_template/prj/libcore-ext/manifest"

  # bdep/bpkg write CRLF on this platform; normalize the template to LF so
  # every scenario except the dedicated CRLF one (S18) gets a clean, LF-only
  # baseline matching the hook's real (Linux) deployment target.
  find "$_template/prj" -type f -print0 | xargs -0 sed -i 's/\r$//'
}

_teardown_suite() {
  [[ -n "$_root_tmp" && -d "$_root_tmp" ]] && rm -rf "$_root_tmp"
}

# Create a fresh git repo (with all 3 packages committed) in a new sandbox.
# Prints the sandbox project dir on stdout.
_new_repo() {
  local _sandbox
  _sandbox=$(mktemp -d "$_root_tmp/sbx.XXXXXX")
  cp -r "$_template/prj" "$_sandbox/prj"
  (
    cd "$_sandbox/prj" &&
      git init -q &&
      git config user.email test@example.org &&
      git config user.name Test &&
      git config core.autocrlf false &&
      mkdir -p .git/hooks &&
      cp "$_hook_checkout" .git/hooks/post-checkout &&
      cp "$_hook_sync" .git/hooks/bdep-sync.sh &&
      chmod +x .git/hooks/post-checkout &&
      git config core.hooksPath .git/hooks &&
      git add -A &&
      git commit -q -m "all packages present"
  ) >/dev/null 2>"$_sandbox/init.err" || {
    echo "FATAL: repo init failed for $_sandbox" >&2
    cat "$_sandbox/init.err" >&2
    exit 1
  }
  printf '%s\n' "$_sandbox/prj"
}

# Remove a package's stanza from packages.manifest (paragraph-mode awk).
_manifest_remove_pkg() {
  local _file="$1" _loc="$2"
  awk -v loc="location: ${_loc}/" '
    BEGIN { RS=""; n=0 }
    $0 !~ loc { blocks[n++]=$0 }
    END {
      for (i=0;i<n;i++) {
        b=blocks[i]
        if (i==0) sub(/^:[ \t]*[0-9]*/, ": 1", b)
        else      sub(/^:[ \t]*[0-9]*/, ":", b)
        printf "%s", b
        printf (i<n-1 ? "\n\n" : "\n")
      }
    }
  ' "$_file" >"$_file.tmp" && mv "$_file.tmp" "$_file"
}

_manifest_add_pkg() {
  local _file="$1" _loc="$2"
  printf '\n:\nlocation: %s/\n' "$_loc" >>"$_file"
}

# Create a bpkg config and init it (optionally scoped to specific packages).
# _mk_cfg <root> <cfg-name> <cfg-dir> [pkg-loc...]
_mk_cfg() {
  local _root="$1" _name="$2" _dir="$3"
  shift 3
  if [[ $# -eq 0 ]]; then
    ( cd "$_root" && bdep init -C "$_dir" "@$_name" cc "config.cxx=$_cxx" )
  else
    local _dargs=() _l
    for _l in "$@"; do _dargs+=(-d "$_root/$_l"); done
    ( cd "$_root" && bdep config create "@$_name" "$_dir" cc "config.cxx=$_cxx" ) &&
      ( cd "$_root" && bdep init "@$_name" "${_dargs[@]}" )
  fi
}

# Run the hook as a plain subprocess (not sourced) so its own `exit` only
# ends the subprocess. Sets _out, _err, _rc.
_run_direct() {
  local _dir="$1" _prev="$2" _new="$3" _branch="$4" _path="${5:-$PATH}"
  local _ef; _ef=$(mktemp)
  _out=$(cd "$_dir" && PATH="$_path" bash "$_hook_sync" "$_prev" "$_new" "$_branch" 2>"$_ef")
  _rc=$?
  _err=$(<"$_ef"); rm -f "$_ef"
}

# Trigger the hook via a real `git checkout`. $1=dir $2=path-to-PATH-override
# (pass "" for the current $PATH), remaining args go straight to `git
# checkout -q`. Sets _out, _err, _rc.
_run_checkout() {
  local _dir="$1" _path="${2:-$PATH}"
  shift 2
  local _ef; _ef=$(mktemp)
  _out=$(cd "$_dir" && PATH="$_path" git checkout -q "$@" 2>"$_ef")
  _rc=$?
  _err=$(<"$_ef"); rm -f "$_ef"
}

_hook_says_ok() { printf '%s' "$_out$_err" | _strip_ansi | grep -q '\[hook/bdep-sync\]:ok'; }
_hook_says_no() { printf '%s' "$_out$_err" | _strip_ansi | grep -q '\[hook/bdep-sync\]:no'; }
_hook_silent()  { [[ -z "$_out" && -z "$_err" ]]; }

_path_without() {
  # print $PATH with the directory containing $1 removed
  local _bin _dir
  _bin=$(command -v "$1") || { printf '%s' "$PATH"; return; }
  _dir=$(dirname "$_bin")
  printf '%s' "$PATH" | tr ':' '\n' | grep -Fxv "$_dir" | paste -sd: -
}

# Extract just the bdep-sync.sh function definitions (no auto-invoke/exit),
# for unit-testing individual parsing helpers directly.
_source_hook_functions() {
  # shellcheck disable=SC1090
  source <(sed '/^_bdep_sync_hook "\$@"/,$d' "$_hook_sync")
}

# ---------------------------------------------------------------------------
# scenarios
# ---------------------------------------------------------------------------

scenario_S1_file_checkout() {
  local _d; _d=$(_new_repo)
  local _sha; _sha=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" HEAD -- README.md
  _check $([[ $_rc -eq 0 ]] && _hook_says_no && echo 0 || echo 1) \
    "S1 file-level checkout (not a branch switch) -> skip" "$_out$_err"
}

scenario_S2_same_commit() {
  local _d; _d=$(_new_repo)
  _run_checkout "$_d" "" HEAD
  _check $([[ $_rc -eq 0 ]] && _hook_says_no && echo 0 || echo 1) \
    "S2 same commit on both sides -> skip" "$_out$_err"
}

scenario_S3_not_bdep_project() {
  local _sandbox; _sandbox=$(mktemp -d "$_root_tmp/sbx.XXXXXX")
  (
    cd "$_sandbox" &&
      git init -q &&
      git config user.email test@example.org && git config user.name Test &&
      mkdir -p .git/hooks &&
      cp "$_hook_checkout" .git/hooks/post-checkout &&
      cp "$_hook_sync" .git/hooks/bdep-sync.sh &&
      chmod +x .git/hooks/post-checkout &&
      git config core.hooksPath .git/hooks &&
      echo one >f.txt && git add -A && git commit -q -m c1 &&
      git checkout -q -b other &&
      echo two >f.txt && git commit -qam c2
  ) >/dev/null 2>&1
  _run_checkout "$_sandbox" "" master
  _check $([[ $_rc -eq 0 ]] && _hook_silent && echo 0 || echo 1) \
    "S3 not a bdep project (.bdep absent) -> fully silent" "$_out$_err"
}

scenario_S4_bdep_not_on_path() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
      git commit -qam "remove libcore-ext" ) >/dev/null 2>&1
  local _stripped; _stripped=$(_path_without bdep)
  _run_checkout "$_d" "$_stripped" HEAD~1
  _check $([[ $_rc -eq 0 ]] && _hook_says_no && echo 0 || echo 1) \
    "S4 bdep not on PATH -> skip (warn)" "$_out$_err"
}

scenario_S5_manifest_unchanged() {
  local _d; _d=$(_new_repo)
  ( cd "$_d" && echo more >>README.md && git commit -qam "touch readme" ) >/dev/null 2>&1
  _run_checkout "$_d" "" HEAD~1
  _check $([[ $_rc -eq 0 ]] && _hook_says_no && echo 0 || echo 1) \
    "S5 packages.manifest unchanged, other files changed -> skip" "$_out$_err"
}

scenario_S6_removed_initialized() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
      git commit -qam "remove libcore-ext" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1   # rewind (throwaway, no-op-ish add)
  _run_checkout "$_d" "" "$_without"                # real transition: with -> without (suspend)
  local _marker="$_d-gcc/libcore-ext/build/bootstrap/src-root.build.suspend"
  local _pass1=1
  [[ $_rc -eq 0 ]] && _hook_says_ok && [[ -f "$_marker" ]] && ! [[ -d "$_d/libcore-ext" ]] && _pass1=0
  _check $_pass1 "S6 package removed, was initialized -> suspend sequence (marker written, purged)" "$_out$_err"

  local _status; _status=$(bpkg pkg-status --all --directory "$_d-gcc" 2>&1)
  _check $([[ "$_status" != *"libcore-ext"* ]] && echo 0 || echo 1) \
    "S6b suspended package purged from bpkg (no longer in pkg-status)" "$_status"

  # restore-guard variant: source kept tracked (only manifest entry removed),
  # cleanup must not delete it (commit 7da33cc).
  local _d2; _d2=$(_new_repo)
  _mk_cfg "$_d2" gcc "$_d2-gcc" >/dev/null 2>&1
  local _with2; _with2=$(git -C "$_d2" rev-parse HEAD)
  ( cd "$_d2" && _manifest_remove_pkg packages.manifest libcore-ext && git commit -qam "drop from manifest only" ) >/dev/null 2>&1
  local _without2; _without2=$(git -C "$_d2" rev-parse HEAD)
  _run_checkout "$_d2" "" "$_with2" >/dev/null 2>&1
  _run_checkout "$_d2" "" "$_without2"
  _check $([[ -d "$_d2/libcore-ext" ]] && echo 0 || echo 1) \
    "S6c restore-guard: manifest-only removal keeps tracked source on disk" "$_out$_err"
}

scenario_S7_removed_never_initialized() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" libcore my-app >/dev/null 2>&1
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
      git commit -qam "remove libcore-ext" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1
  _run_checkout "$_d" "" "$_without"
  _check $([[ $_rc -eq 0 ]] && _hook_says_ok && echo 0 || echo 1) \
    "S7 package removed, never initialized -> skip cleanly, no error" "$_out$_err"
}

scenario_S8_added_suspend_found() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
      git commit -qam "remove libcore-ext" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1   # rewind (throwaway)
  _run_checkout "$_d" "" "$_without"                # suspend
  _run_checkout "$_d" "" "$_with"                   # resume
  local _marker="$_d-gcc/libcore-ext/build/bootstrap/src-root.build.suspend"
  local _srb="$_d-gcc/libcore-ext/build/bootstrap/src-root.build"
  _check $([[ $_rc -eq 0 ]] && ! [[ -f "$_marker" ]] && [[ -f "$_srb" ]] && echo 0 || echo 1) \
    "S8 package added, .suspend found -> resume via bdep init --no-sync" "$_out$_err"
}

scenario_S9_added_no_suspend() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" libcore my-app >/dev/null 2>&1   # libcore-ext never initialized here
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
      git commit -qam "remove libcore-ext" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1
  _run_checkout "$_d" "" "$_without"
  _run_checkout "$_d" "" "$_with"
  _check $([[ $_rc -eq 0 ]] && _hook_says_ok && ! [[ -d "$_d-gcc/libcore-ext" ]] && echo 0 || echo 1) \
    "S9 package added, no .suspend -> skip (never had an out-tree here)" "$_out$_err"
}

scenario_S10_both_removed_and_added() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  local _c1; _c1=$(git -C "$_d" rev-parse HEAD)   # libcore, my-app, libcore-ext
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
      git commit -qam "remove libcore-ext" ) >/dev/null 2>&1
  local _c2; _c2=$(git -C "$_d" rev-parse HEAD)   # libcore, my-app
  ( cd "$_d" &&
      _manifest_remove_pkg packages.manifest my-app && git rm -rq my-app &&
      git checkout -q "$_c1" -- libcore-ext &&
      _manifest_add_pkg packages.manifest libcore-ext &&
      git add -A && git commit -qam "swap: drop my-app, bring back libcore-ext" ) >/dev/null 2>&1
  local _c3; _c3=$(git -C "$_d" rev-parse HEAD)   # libcore, libcore-ext (no my-app)
  _run_checkout "$_d" "" "$_c1" >/dev/null 2>&1   # rewind (throwaway)
  _run_checkout "$_d" "" "$_c2"                    # suspend libcore-ext, leaves .suspend marker
  _run_checkout "$_d" "" "$_c3"                    # real test: suspend my-app AND resume libcore-ext together
  local _my_marker="$_d-gcc/my-app/build/bootstrap/src-root.build.suspend"
  local _ext_srb="$_d-gcc/libcore-ext/build/bootstrap/src-root.build"
  local _ext_suspend="$_d-gcc/libcore-ext/build/bootstrap/src-root.build.suspend"
  _check $([[ $_rc -eq 0 ]] && [[ -f "$_my_marker" ]] && [[ -f "$_ext_srb" ]] && ! [[ -f "$_ext_suspend" ]] && echo 0 || echo 1) \
    "S10 both removed and added in one switch -> suspend all then resume all" "$_out$_err"
}

scenario_S11_fresh_clone() {
  local _d; _d=$(_new_repo)
  local _new; _new=$(git -C "$_d" rev-parse HEAD)
  _run_direct "$_d" "0000000000000000000000000000000000000000" "$_new" 1
  _check $([[ $_rc -eq 0 ]] && echo 0 || echo 1) \
    "S11 fresh clone / initial checkout (all-zero prev SHA) doesn't crash" "$_out$_err"
}

scenario_S12_rebase_main_worktree() {
  local _d; _d=$(_new_repo)
  local _sha; _sha=$(git -C "$_d" rev-parse HEAD)
  mkdir -p "$_d/.git/rebase-merge"
  _run_direct "$_d" "$_sha" "$_sha" 1
  local _r=1
  [[ $_rc -eq 0 ]] && _hook_silent && _r=0
  rm -rf "$_d/.git/rebase-merge"
  _check $_r "S12 interactive rebase in progress (main worktree) -> skip silently" "$_out$_err"
}

scenario_S13_rebase_linked_worktree() {
  local _d; _d=$(_new_repo)
  local _wt="$_root_tmp/$(basename "$_d")-wt"
  ( cd "$_d" && git branch wtbranch && git worktree add -q "$_wt" wtbranch ) >/dev/null 2>&1
  local _gitdir; _gitdir=$(git -C "$_wt" rev-parse --git-dir)
  # normalize to an absolute path usable from any cwd
  [[ "$_gitdir" = /* || "$_gitdir" =~ ^[A-Za-z]: ]] || _gitdir="$_wt/$_gitdir"
  mkdir -p "$_gitdir/rebase-merge"
  local _sha; _sha=$(git -C "$_wt" rev-parse HEAD)
  _run_direct "$_wt" "$_sha" "$_sha" 1
  local _r=1
  [[ $_rc -eq 0 ]] && _hook_silent && _r=0
  rm -rf "$_gitdir/rebase-merge"
  _check $_r "S13 interactive rebase in progress in a LINKED WORKTREE -> must still skip" "$_out$_err"
}

scenario_S14_removed_multi_config() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc1 "$_d-gcc1" >/dev/null 2>&1
  _mk_cfg "$_d" gcc2 "$_d-gcc2" >/dev/null 2>&1
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
      git commit -qam "remove libcore-ext" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1
  _run_checkout "$_d" "" "$_without"
  local _r=1
  [[ $_rc -eq 0 ]] && _hook_says_ok \
    && [[ -f "$_d-gcc1/libcore-ext/build/bootstrap/src-root.build.suspend" ]] \
    && [[ -f "$_d-gcc2/libcore-ext/build/bootstrap/src-root.build.suspend" ]] \
    && _r=0
  _check $_r "S14 package removed+initialized in two configs -> both suspended" "$_out$_err"
}

scenario_S15_kept_dependent() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore && git rm -rq libcore &&
      git commit -qam "remove libcore (libcore-ext keeps depending on it)" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1
  _run_checkout "$_d" "" "$_without"
  local _r=1
  [[ $_rc -eq 0 ]] && _hook_says_ok \
    && [[ -f "$_d-gcc/libcore/build/bootstrap/src-root.build.suspend" ]] \
    && [[ -f "$_d-gcc/libcore-ext/build/bootstrap/src-root.build" ]] \
    && ! [[ -f "$_d-gcc/libcore-ext/build/bootstrap/src-root.build.suspend" ]] \
    && _r=0
  _check $_r "S15 removed package's kept dependent gets disfigured then src-root.build restored" "$_out$_err"
}

scenario_S16_hyphenated_name() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" && _manifest_remove_pkg packages.manifest my-app && git rm -rq my-app &&
      git commit -qam "remove my-app" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1
  _run_checkout "$_d" "" "$_without"
  local _r=1
  # Note: git relays a hook's own stdout through what we capture here as
  # stderr (documented git behavior, so normal "deinitializing package"/
  # "[hook/bdep-sync]:ok" lines legitimately show up in $_err) -- so check
  # for an actual bash runtime-error signature, not merely non-empty $_err.
  [[ $_rc -eq 0 ]] && _hook_says_ok \
    && [[ -f "$_d-gcc/my-app/build/bootstrap/src-root.build.suspend" ]] \
    && ! printf '%s' "$_err" | grep -Eq '\.sh: line [0-9]+:|not a valid identifier|invalid variable name|command not found' \
    && _r=0
  _check $_r "S16 hyphenated package name (my-app) suspends cleanly with zero stderr noise" "$_out$_err"
}

scenario_S17_resume_cross_config() {
  local _d; _d=$(_new_repo)
  # cfgA gets libcore + libcore-ext (not my-app); cfgB gets libcore + my-app (not libcore-ext)
  _mk_cfg "$_d" cfgA "$_d-cfgA" libcore libcore-ext >/dev/null 2>&1
  _mk_cfg "$_d" cfgB "$_d-cfgB" libcore my-app >/dev/null 2>&1
  local _with; _with=$(git -C "$_d" rev-parse HEAD)
  ( cd "$_d" &&
      _manifest_remove_pkg packages.manifest libcore-ext &&
      _manifest_remove_pkg packages.manifest my-app &&
      git rm -rq libcore-ext my-app &&
      git commit -qam "remove libcore-ext and my-app" ) >/dev/null 2>&1
  local _without; _without=$(git -C "$_d" rev-parse HEAD)
  _run_checkout "$_d" "" "$_with" >/dev/null 2>&1  # rewind (throwaway)
  _run_checkout "$_d" "" "$_without"                # suspends both, each in only one cfg
  _run_checkout "$_d" "" "$_with"                   # resumes both together
  local _r=1
  if [[ $_rc -eq 0 ]] && _hook_says_ok; then
    local _extA="$_d-cfgA/libcore-ext/build/bootstrap/src-root.build"
    local _extB="$_d-cfgB/libcore-ext/build/bootstrap/src-root.build"
    local _appA="$_d-cfgA/my-app/build/bootstrap/src-root.build"
    local _appB="$_d-cfgB/my-app/build/bootstrap/src-root.build"
    [[ -f "$_extA" ]] && ! [[ -e "$_d-cfgB/libcore-ext" ]] \
      && [[ -f "$_appB" ]] && ! [[ -e "$_d-cfgA/my-app" ]] \
      && _r=0
  fi
  _check $_r "S17 resume must not cross-initialize a package into a config it was never part of" "$_out$_err"
}

scenario_S18_crlf_manifest() {
  (
    _source_hook_functions
    pkg=$(_bdep_sync_pkg_name <(printf 'name: my-app\r\nversion: 1.0.0\r\n'))
    loc=$(_bdep_sync_parse_locs <(printf 'location: my-app/\r\n\r\nlocation: libcore/\r\n'))
    [[ "$pkg" == "my-app" && "$(printf '%s' "$loc" | head -1)" == "my-app" ]]
  )
  _check $? "S18 CRLF-terminated manifest lines parse without a trailing \\r" ""
}

scenario_S19_cfg_dirs_shape() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  (
    cd "$_d" || exit 1
    _source_hook_functions
    cfg=$(_bdep_sync_cfg_dirs "$_d")
    [[ "$cfg" != */ ]] && [[ -n "$cfg" ]]
  )
  _check $? "S19 _bdep_sync_cfg_dirs strips the trailing slash bdep config list emits" ""
}

scenario_S20_broken_state() {
  local _d; _d=$(_new_repo)
  _mk_cfg "$_d" gcc "$_d-gcc" >/dev/null 2>&1
  # Attempt to force a genuine bpkg "broken" state by deleting the actual
  # project source out from under an already-configured package.
  mv "$_d/libcore-ext" "$_d/libcore-ext.bak"
  local _status; _status=$(bpkg pkg-status --all --directory "$_d-gcc" 2>&1)
  mv "$_d/libcore-ext.bak" "$_d/libcore-ext"
  if [[ "$_status" == *broken* ]]; then
    mv "$_d/libcore-ext" "$_d/libcore-ext.bak"
    local _with; _with=$(git -C "$_d" rev-parse HEAD)
    ( cd "$_d" && _manifest_remove_pkg packages.manifest libcore-ext && git rm -rq libcore-ext &&
        git commit -qam "remove broken libcore-ext" ) >/dev/null 2>&1
    local _without; _without=$(git -C "$_d" rev-parse HEAD)
    _run_checkout "$_d" "" "$_with" >/dev/null 2>&1
    _run_checkout "$_d" "" "$_without"
    _check $([[ $_rc -eq 0 ]] && echo 0 || echo 1) \
      "S20 (best-effort) broken package doesn't wedge the hook" "$_out$_err"
  else
    printf '%s SKIP %s%s\n' "$clr_warn" "$clr_def" \
      "S20 (best-effort) broken bpkg state not reproducible in this environment -- documented gap, not counted"
  fi
}

# ---------------------------------------------------------------------------
# runner
# ---------------------------------------------------------------------------

_all_scenarios=(
  scenario_S1_file_checkout
  scenario_S2_same_commit
  scenario_S3_not_bdep_project
  scenario_S4_bdep_not_on_path
  scenario_S5_manifest_unchanged
  scenario_S6_removed_initialized
  scenario_S7_removed_never_initialized
  scenario_S8_added_suspend_found
  scenario_S9_added_no_suspend
  scenario_S10_both_removed_and_added
  scenario_S11_fresh_clone
  scenario_S12_rebase_main_worktree
  scenario_S13_rebase_linked_worktree
  scenario_S14_removed_multi_config
  scenario_S15_kept_dependent
  scenario_S16_hyphenated_name
  scenario_S17_resume_cross_config
  scenario_S18_crlf_manifest
  scenario_S19_cfg_dirs_shape
  scenario_S20_broken_state
)

_setup_suite
trap _teardown_suite EXIT

for _s in "${_all_scenarios[@]}"; do
  [[ -n "$_filter" && "$_s" != *"$_filter"* ]] && continue
  "$_s"
done

echo "-----"
printf 'total: %d passed, %d failed\n' "$_pass" "$_fail"
[[ $_fail -eq 0 ]]
