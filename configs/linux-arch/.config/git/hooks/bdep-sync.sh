# bdep-sync: suspend/resume bdep packages when switching git branches.
#
# requires: bdep, bpkg, bash >=4.3
#
# OVERVIEW
#   Keeps bdep/bpkg databases and out-tree markers consistent with
#   packages.manifest when a branch checkout adds or removes packages.
#
#   suspend  bdep deinit + bpkg cleanup + rename src-root.build -> .suspend
#   resume   rename .suspend -> src-root.build + bdep init --no-sync
#
#   The package name (read from each package's manifest `name:` field) is used
#   for all bdep/bpkg calls and to locate the out-tree at <cfg-dir>/<name>/.
#
# SUSPEND SEQUENCE
#   packages.manifest is temporarily replaced with the previous-branch version
#   so bdep can resolve all package names in one pass.  All removed sources are
#   git-restored before any deinit so every manifest listed there exists.
#
#   For each removed package:
#     1. Skip if no src-root.build exists in any configuration (never initialized;
#        no build state to preserve and bdep deinit would fail on the package).
#     2. bdep deinit --force --all
#          On forward configs this calls b disfigure:src@out,forward (needs
#          src-root.build to bootstrap the out-root; no-op when the source has
#          no out-root.build, which is typical for git-managed trees).
#          "not initialized in any" is non-fatal: bdep db is already clean, so
#          fall through to bpkg/filesystem cleanup (the two databases are independent).
#          Other failures: leave this package intact and skip steps 3-4.
#     3. bpkg cleanup per configuration (skipped when no src-root.build):
#          configured -> pkg-disfigure --keep-out --keep-config -> pkg-purge
#          unpacked   -> pkg-purge only  (out_root already null; no b invocation)
#          other      -> no bpkg action
#     4. Rename src-root.build -> src-root.build.suspend.
#     5. Restore new-branch packages.manifest; remove git-restored source trees.
#
# SCENARIOS
#
#   Condition                    Action
#   ===========================  ==============================================
#   not a branch checkout        skip (warn)
#   same commit on both sides    skip (warn)
#   not a bdep project           skip (warn)
#   bdep not on PATH             skip (warn)
#   packages.manifest unchanged  skip (warn)
#   pkg removed, initialized     SUSPEND SEQUENCE above
#   pkg removed, never init-ed   skip (no out-tree to preserve)
#   pkg added, .suspend found    .suspend -> src-root.build; bdep init --no-sync
#   pkg added, no .suspend       skip (never had an out-tree here; needs manual init)
#   both removed and added       suspend all first, then resume all
#
# ENVIRONMENT
#   BDEP_SYNC_AUTO_CLEAN  When set, suspended source trees are removed with
#                         `rm -rf`. Default: remove only git-tracked files,
#                         leaving untracked content (build artefacts, etc.)
#                         in place.
#

_bdep_sync_pkg_name() {
  # Print the package name from the manifest file at $1.
  local _line
  while IFS= read -r _line; do
    [[ "$_line" == name:* ]] || continue
    _line="${_line#name:}"
    _line="${_line#"${_line%%[! ]*}"}"  # ltrim spaces
    printf '%s\n' "$_line"
    return
  done < "$1"
}

_bdep_sync_parse_locs() {
  # Print package locations from the packages.manifest file at path $1.
  # Trailing slash and surrounding whitespace stripped.
  local _line _loc
  while IFS= read -r _line; do
    [[ "$_line" == location:* ]] || continue
    _loc="${_line#location:}"
    _loc="${_loc#"${_loc%%[! ]*}"}"  # ltrim spaces
    _loc="${_loc%/}"                  # strip trailing slash
    printf '%s\n' "$_loc"
  done < "$1"
}

_bdep_sync_cfg_dirs() {
  # Print bdep configuration directories for project at $1, one per line,
  # with forward slashes (normalises Windows backslash paths from bdep output).
  local _line _path
  while IFS= read -r _line; do
    [[ -z "$_line" ]] && continue
    [[ "$_line" == @* ]] && _line="${_line#* }"  # strip @name prefix
    _path="${_line%% *}"                          # first field = cfg-dir path
    printf '%s\n' "${_path//\\//}"               # normalise to forward slashes
  done < <(bdep config list --directory "$1" 2>/dev/null)
}

_bdep_sync_loc_diff() {
  # Compute removed/added locations between $1 (prev commit) and the current
  # packages.manifest under project root $2.  Results stored in the caller
  # variables named by $3 (removed) and $4 (added) via namerefs.
  local _prev="$1" _root="$2"
  local -n _removed="$3" _added="$4"
  local -A _prev_set=() _curr_set=()
  local _loc

  while IFS= read -r _loc; do
    [[ -n "$_loc" ]] && _prev_set["$_loc"]=1
  done < <(_bdep_sync_parse_locs <(git show "$_prev:packages.manifest" 2>/dev/null))

  if [[ -f "$_root/packages.manifest" ]]; then
    while IFS= read -r _loc; do
      [[ -n "$_loc" ]] && _curr_set["$_loc"]=1
    done < <(_bdep_sync_parse_locs "$_root/packages.manifest")
  fi

  _removed="" _added=""
  for _loc in "${!_prev_set[@]}"; do
    [[ -z "${_curr_set[$_loc]+x}" ]] && _removed+="${_loc}"$'\n'
  done
  for _loc in "${!_curr_set[@]}"; do
    [[ -z "${_prev_set[$_loc]+x}" ]] && _added+="${_loc}"$'\n'
  done
}

_bdep_sync_cleanup() {
  # Restore packages.manifest and remove git-restored source trees created
  # during the suspend phase.  Registered as EXIT trap for early exits and
  # called explicitly at suspend end.  Accesses _bdep_sync_hook locals
  # (bak, root, restored_locs, prev_head, _manifest_swapped) via dynamic scoping.
  trap - EXIT
  if [[ "${_manifest_swapped:-0}" -eq 1 ]]; then
    if [[ -n "${bak:-}" ]]; then
      mv "$bak" "$root/packages.manifest"
    else
      rm -f "$root/packages.manifest"
    fi
  fi
  local _loc _rel _f
  for _loc in "${restored_locs[@]}"; do
    _rel="${_loc#"$root/"}"
    if [[ -n "${BDEP_SYNC_AUTO_CLEAN-}" ]]; then
      rm -rf "$_loc"
    else
      while IFS= read -r _f; do
        rm -f "$root/$_f"
      done < <(git -C "$root" ls-tree -r --name-only "$prev_head" -- "$_rel" 2>/dev/null)
      find "$_loc" -depth -type d -empty -delete 2>/dev/null
    fi
  done
}

_bdep_sync_hook() {
  local prev_head="$1" new_head="$2" is_branch="$3"
  local clr_ok=$'\e[1;32m' clr_warn=$'\e[1;33m' clr_err=$'\e[1;31m' clr_def=$'\e[1;0m'
  local clr_res="" root="" removed="" added=""
  local cfg loc pkg src bak="" _manifest_swapped=0 suspend _err err_out="" _ok _status _deinit_ok _any _found _pname
  local -a cfg_dirs restored_locs=() _resume_cfgs _suspend_pkgs _bdep_order _ordered

  # Guards: skip unless this is a branch switch with actual manifest changes
  [[ "$is_branch" != "1" || "$prev_head" == "$new_head" ]] && clr_res=$clr_warn
  if [[ -z "$clr_res" ]]; then
    root=$(git rev-parse --show-toplevel 2>/dev/null) || clr_res=$clr_warn
  fi
  if [[ -z "$clr_res" ]]; then
    [[ -d "$root/.bdep" ]] || clr_res=$clr_warn
    command -v bdep >/dev/null 2>&1 || clr_res=$clr_warn
  fi
  if [[ -z "$clr_res" ]]; then
    _bdep_sync_loc_diff "$prev_head" "$root" removed added
    [[ -z "$removed" && -z "$added" ]] && clr_res=$clr_warn
  fi

  if [[ -z "$clr_res" ]]; then
    mapfile -t cfg_dirs < <(_bdep_sync_cfg_dirs "$root")

    # == SUSPEND removed packages ==============================================
    if [[ -n "$removed" ]]; then
      if [[ -f "$root/packages.manifest" ]]; then
        bak="$root/packages.manifest.bdep-sync-bak"
        cp "$root/packages.manifest" "$bak"
      fi
      git show "$prev_head:packages.manifest" > "$root/packages.manifest"
      _manifest_swapped=1
      trap _bdep_sync_cleanup EXIT

      # Restore ALL removed sources before any deinit; bdep load_package_names
      # reads every location in packages.manifest in one pass so all must exist.
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        git -C "$root" restore --quiet --source="$prev_head" --worktree -- "$loc" 2>/dev/null
        restored_locs+=("$root/$loc")
      done <<<"$removed"

      # Capture build-order from bdep (dependencies-first) now, while packages
      # are still initialized.  Non-indented lines in 'bdep status --immediate'
      # output are project packages in manifest/dependency order; reversing them
      # gives the correct disfigure order (dependents first) for Phase 2.
      _bdep_order=()
      while IFS= read -r _pname; do
        [[ "${_pname:0:1}" == ' ' || -z "$_pname" ]] && continue
        _bdep_order+=("${_pname%% *}")
      done < <(bdep status --immediate --directory "$root" 2>/dev/null)

      # Phase 1: bdep deinit (cleans bdep DB) and collect packages with out-trees.
      # bdep deinit --force skips bpkg drop, so the bpkg DB is cleaned separately
      # in phase 2.  Packages that fail deinit for reasons other than "not
      # initialized in any" are skipped entirely.
      _suspend_pkgs=()
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        pkg=$(_bdep_sync_pkg_name "$root/$loc/manifest")

        # Skip if no out-tree exists in any configuration: the package was never
        # initialized, so bdep deinit would fail and there is nothing to suspend.
        _any=0
        for cfg in "${cfg_dirs[@]}"; do
          [[ -f "$cfg/$pkg/build/bootstrap/src-root.build" ]] && { _any=1; break; }
        done
        [[ $_any -eq 0 ]] && continue

        printf 'deinitializing package %s\n' "$pkg"
        _deinit_ok=1
        _err=$(bdep deinit --force --all --directory "$root" "$pkg" 2>&1) || _deinit_ok=0
        if [[ $_deinit_ok -eq 0 ]]; then
          # "not initialized in any" means the bdep db is already clean; still
          # run bpkg/filesystem cleanup below (bdep and bpkg dbs are independent).
          if [[ "$_err" != *"not initialized in any"* ]]; then
            err_out+="[bdep deinit $pkg]: $_err"$'\n'
            clr_res=$clr_err; continue
          fi
        fi

        _suspend_pkgs+=("$pkg")
      done <<<"$removed"

      # Phase 2: bpkg cleanup + filesystem rename in disfigure order.
      # Reverse the bdep build-order (dependencies-first) to get dependents-first
      # order so pkg-disfigure never encounters "still has dependents" errors.
      _ordered=()
      for (( i=${#_bdep_order[@]}-1; i>=0; i-- )); do
        pkg="${_bdep_order[$i]}"
        _found=0
        for _pname in "${_suspend_pkgs[@]}"; do
          [[ "$_pname" == "$pkg" ]] && { _found=1; break; }
        done
        [[ $_found -eq 0 ]] && continue
        _found=0
        for _pname in "${_ordered[@]}"; do
          [[ "$_pname" == "$pkg" ]] && { _found=1; break; }
        done
        [[ $_found -eq 0 ]] && _ordered+=("$pkg")
      done
      # Append any packages absent from bdep output (e.g. not initialized).
      for pkg in "${_suspend_pkgs[@]}"; do
        _found=0
        for _pname in "${_ordered[@]}"; do
          [[ "$_pname" == "$pkg" ]] && { _found=1; break; }
        done
        [[ $_found -eq 0 ]] && _ordered+=("$pkg")
      done

      for pkg in "${_ordered[@]}"; do
        for cfg in "${cfg_dirs[@]}"; do
          [[ -d "$cfg" ]] || continue
          src="$cfg/$pkg/build/bootstrap/src-root.build"
          [[ -f "$src" ]] || continue
          _status=$(bpkg pkg-status --directory "$cfg" "$pkg" 2>/dev/null)
          _ok=1
          if [[ "$_status" == *configured* ]]; then
            if ! _err=$(bpkg pkg-disfigure --directory "$cfg" \
                          --keep-out --keep-config "$pkg" 2>&1); then
              err_out+="[bpkg disfigure $pkg @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err; _ok=0
            fi
          fi
          if [[ $_ok -eq 1 && ( "$_status" == *configured* || "$_status" == *unpacked* ) ]]; then
            if ! _err=$(bpkg pkg-purge --directory "$cfg" "$pkg" 2>&1); then
              err_out+="[bpkg purge $pkg @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err
            fi
          fi
          mv "$src" "${src}.suspend"
        done
      done

      _bdep_sync_cleanup
    fi

    # == RESUME reappearing packages ===========================================
    if [[ -n "$added" ]]; then
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        pkg=$(_bdep_sync_pkg_name "$root/$loc/manifest")
        _resume_cfgs=()
        for cfg in "${cfg_dirs[@]}"; do
          [[ -d "$cfg" ]] || continue
          suspend="$cfg/$pkg/build/bootstrap/src-root.build.suspend"
          [[ -f "$suspend" ]] || continue
          mv "$suspend" "${suspend%.suspend}"
          _resume_cfgs+=("$cfg")
        done
        [[ ${#_resume_cfgs[@]} -eq 0 ]] && continue
        # Init only in the cfgs that had .suspend — passing --all would conflict
        # when multiple forwarded configurations exist in the project.
        if ! bdep init --no-sync "${_resume_cfgs[@]}" -d "$root/$loc"; then
          clr_res=$clr_err
        fi
      done <<<"$added"
    fi
  fi

  [[ -n "$err_out" ]] && printf '%s' "$err_out" >&2
  local res=${clr_res:+no}
  printf '[hook/%s]:%b%s%b\n' "bdep-sync" ${clr_res:-$clr_ok} ${res:-ok} $clr_def
  [[ "${clr_res:-$clr_ok}" != "$clr_err" ]]
}

_bdep_sync_hook "$@"
_bdep_sync_rc=$?
unset -f _bdep_sync_hook _bdep_sync_cleanup _bdep_sync_loc_diff _bdep_sync_parse_locs _bdep_sync_cfg_dirs _bdep_sync_pkg_name
exit $_bdep_sync_rc
