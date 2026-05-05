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
#   Phase 1 — bdep deinit:
#     Packages that have no src-root.build in any configuration are skipped
#     (never initialized; bdep deinit would fail and nothing to preserve).
#     All remaining packages are deinited in a single bdep call; bdep resolves
#     dependency order internally.  --force skips bpkg drop, leaving the bpkg
#     DB for Phase 2.  "not initialized in" is non-fatal (bdep DB already
#     clean).  Any other failure aborts Phase 2 for all packages.
#
#   Phase 2 — bpkg cleanup + marker preservation:
#     One bpkg pkg-status call per configuration captures state.  src-root.build
#     content is saved to memory for all configured packages.  A single
#     pkg-drop --drop-dependent call disfigures suspended packages and any kept
#     dependents together (bpkg resolves the order internally).  Only suspended
#     packages are purged; kept dependents are left unpacked and re-configured
#     by the next bdep sync.  .suspend markers are written from saved content;
#     src-root.build is restored for kept packages that pkg-drop disfigured.
#       suspended -> [save] -> pkg-drop --drop-dependent --disfigure-only -> pkg-purge -> [write .suspend]
#       kept dep -> [save] -> disfigured by pkg-drop as dependent -> [restore src-root.build]
#       unpacked -> [save if present] -> pkg-purge -> [write .suspend]
#       other/absent -> no bpkg action (bdep DB already clean)
#
#   Cleanup: restore new-branch packages.manifest; remove git-restored trees.
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
  local cfg loc pkg src bak="" _manifest_swapped=0 suspend _err err_out="" _ok _any _found_any
  local -a cfg_dirs restored_locs=() _suspend_pkgs

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

      # Restore removed sources so bdep can read all package manifests in one
      # pass.  Use the manifest file as the presence test: if $loc/manifest is
      # tracked in the new HEAD the source is properly present (removed from
      # packages.manifest but kept in the git tree); skip restore so cleanup
      # never deletes those files.  When only an empty skeleton (e.g. committed
      # out-root.build artifacts) or nothing is tracked, restore from prev HEAD
      # and schedule the location for cleanup.
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        if [[ -z "$(git -C "$root" ls-tree "$new_head" "$loc/manifest" 2>/dev/null)" ]]; then
          git -C "$root" restore --quiet --source="$prev_head" --worktree -- "$loc" 2>/dev/null
          restored_locs+=("$root/$loc")
        fi
      done <<<"$removed"

      # Collect packages that have an out-tree and need suspension.
      # Packages never initialized (no src-root.build anywhere) are skipped:
      # bdep deinit would fail on them and there is nothing to preserve.
      _suspend_pkgs=()
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        pkg=$(_bdep_sync_pkg_name "$root/$loc/manifest")
        _any=0
        for cfg in "${cfg_dirs[@]}"; do
          [[ -f "$cfg/$pkg/build/bootstrap/src-root.build" ]] && { _any=1; break; }
        done
        [[ $_any -eq 0 ]] && continue
        _suspend_pkgs+=("$pkg")
      done <<<"$removed"

      if [[ ${#_suspend_pkgs[@]} -gt 0 ]]; then
        # Phase 1: single bdep deinit call for all packages.
        # bdep resolves dependency order internally; --force skips bpkg drop so
        # the bpkg DB is left for Phase 2 cleanup.
        printf 'deinitializing package %s\n' "${_suspend_pkgs[@]}"
        if ! _err=$(bdep deinit --force --all --directory "$root" \
                      "${_suspend_pkgs[@]}" 2>&1); then
          # "not initialized in" means the bdep DB is already clean; proceed
          # with Phase 2 (bpkg DB and bdep DB are independent).
          # Any other failure is hard: skip bpkg+filesystem cleanup for all.
          if [[ "$_err" != *"not initialized in"* ]]; then
            err_out+="[bdep deinit]: $_err"$'\n'
            clr_res=$clr_err
            _suspend_pkgs=()
          fi
        fi

        # Phase 2: bpkg cleanup + marker preservation.
        # Save src-root.build content for suspended + kept packages.
        # --drop-dependent handles any kept packages that depend on suspended ones
        # in one call.  Only suspended packages are purged; kept dependents are
        # left unpacked and re-configured by the next bdep sync.
        # .suspend markers are written from saved content; src-root.build is
        # restored for kept packages that --drop-dependent disfigured.
        for cfg in "${cfg_dirs[@]}"; do
          [[ -d "$cfg" ]] || continue

          # Suspended packages with a build marker in this cfg.
          local -a _cfg_pkgs=()
          for pkg in "${_suspend_pkgs[@]}"; do
            [[ -f "$cfg/$pkg/build/bootstrap/src-root.build" ]] && _cfg_pkgs+=("$pkg")
          done
          [[ "${#_cfg_pkgs[@]}" -eq 0 ]] && continue

          # Check bpkg state once.
          local -A _bpkg_state=() _bpkg_failed=() _saved_srb=() _suspended_set=()
          local _line _pname
          while IFS= read -r _line; do
            _pname="${_line#!}"; _pname="${_pname%% *}"
            [[ -z "$_pname" ]] && continue
            if   [[ "$_line" == *configured* ]]; then _bpkg_state["$_pname"]=configured
            elif [[ "$_line" == *unpacked*   ]]; then _bpkg_state["$_pname"]=unpacked
            fi
          done < <(bpkg pkg-status --directory "$cfg" 2>/dev/null)

          # Save src-root.build content for all configured packages and mark
          # which are being suspended.
          for _pname in "${!_bpkg_state[@]}"; do
            src="$cfg/$_pname/build/bootstrap/src-root.build"
            [[ -f "$src" ]] && _saved_srb["$_pname"]=$(<"$src")
          done
          for pkg in "${_cfg_pkgs[@]}"; do
            _suspended_set["$pkg"]=1
            [[ -v "_saved_srb[$pkg]" ]] && continue
            src="$cfg/$pkg/build/bootstrap/src-root.build"
            [[ -f "$src" ]] && _saved_srb["$pkg"]=$(<"$src")
          done

          # Disfigure Phase: one pkg-drop call handles suspended pkgs + any kept
          # dependents; bpkg resolves the dependency order internally.
          local -a _to_disfigure=()
          local _disfigure_ok=1
          for pkg in "${_cfg_pkgs[@]}"; do
            [[ "${_bpkg_state[$pkg]:-}" == configured ]] && _to_disfigure+=("$pkg")
          done
          if [[ "${#_to_disfigure[@]}" -gt 0 ]]; then
            if ! _err=$(bpkg pkg-drop --drop-dependent --disfigure-only --yes \
                          --directory "$cfg" "${_to_disfigure[@]}" 2>&1); then
              err_out+="[bpkg drop/disfigure @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err
              for pkg in "${_to_disfigure[@]}"; do _bpkg_failed["$pkg"]=1; done
              _disfigure_ok=0
            fi
          fi

          # Purge Phase: only suspended packages (kept dependents stay unpacked).
          for pkg in "${_cfg_pkgs[@]}"; do
            [[ -n "${_bpkg_failed[$pkg]+x}" ]] && continue
            [[ "${_bpkg_state[$pkg]:-}" == configured || \
               "${_bpkg_state[$pkg]:-}" == unpacked ]] || continue
            if ! _err=$(bpkg pkg-purge --directory "$cfg" "$pkg" 2>&1); then
              err_out+="[bpkg purge $pkg @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err
              _bpkg_failed["$pkg"]=1
            fi
          done

          # Write .suspend markers for suspended packages from saved content.
          for pkg in "${_cfg_pkgs[@]}"; do
            [[ -n "${_bpkg_failed[$pkg]+x}" ]] && continue
            [[ -v "_saved_srb[$pkg]" ]] || continue
            local srb_dir="$cfg/$pkg/build/bootstrap"
            mkdir -p "$srb_dir"
            printf '%s\n' "${_saved_srb[$pkg]}" > "$srb_dir/src-root.build.suspend"
          done

          # Restore src-root.build for kept packages disfigured as dependents.
          [[ $_disfigure_ok -eq 0 ]] && continue
          for _pname in "${!_saved_srb[@]}"; do
            [[ -n "${_suspended_set[$_pname]+x}" ]] && continue
            srb_dir="$cfg/$_pname/build/bootstrap"
            mkdir -p "$srb_dir"
            printf '%s\n' "${_saved_srb[$_pname]}" > "$srb_dir/src-root.build"
          done
        done
      fi

      _bdep_sync_cleanup
    fi

    # == RESUME reappearing packages ===========================================
    if [[ -n "$added" ]]; then
      # First pass: rename markers and collect cfg union + package dirs.
      local -a _resume_pkg_dirs=() _resume_cfgs=()
      local -A _resume_seen_cfg=()
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        pkg=$(_bdep_sync_pkg_name "$root/$loc/manifest")
        _found_any=0
        for cfg in "${cfg_dirs[@]}"; do
          [[ -d "$cfg" ]] || continue
          suspend="$cfg/$pkg/build/bootstrap/src-root.build.suspend"
          [[ -f "$suspend" ]] || continue
          mv "$suspend" "${suspend%.suspend}"
          _found_any=1
          if [[ -z "${_resume_seen_cfg[$cfg]+x}" ]]; then
            _resume_seen_cfg["$cfg"]=1
            _resume_cfgs+=("$cfg")
          fi
        done
        [[ $_found_any -eq 0 ]] && continue
        printf 'initializing package %s\n' "$pkg"
        _resume_pkg_dirs+=( "-d" "$root/$loc" )
      done <<<"$added"
      # Single bdep init call for all resumed packages across the cfg union.
      # All packages in _resume_pkg_dirs have src-root.build in every cfg in
      # _resume_cfgs (the union of cfgs that held .suspend markers).
      if [[ ${#_resume_pkg_dirs[@]} -gt 0 ]]; then
        if ! bdep init --no-sync "${_resume_cfgs[@]}" "${_resume_pkg_dirs[@]}"; then
          clr_res=$clr_err
        fi
      fi
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
