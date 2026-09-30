# bdep-sync: suspend/resume bdep packages when switching git branches.
#
# requires: bdep, bpkg, bash >=3.2
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
#   Phase 1 - bdep deinit:
#     Packages that have no src-root.build in any configuration are skipped
#     (never initialized; bdep deinit would fail and nothing to preserve).
#     All remaining packages are deinited in a single bdep call; bdep resolves
#     dependency order internally.  --force skips bpkg drop, leaving the bpkg
#     DB for Phase 2.  "not initialized in" is non-fatal (bdep DB already
#     clean).  Any other failure aborts Phase 2 for all packages.
#
#   Phase 2 - bpkg cleanup + marker preservation:
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
    _line="${_line%$'\r'}"  # strip CR (CRLF-checked-out manifest)
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
    _line="${_line%$'\r'}"  # strip CR (CRLF-checked-out manifest)
    [[ "$_line" == location:* ]] || continue
    _loc="${_line#location:}"
    _loc="${_loc#"${_loc%%[! ]*}"}"  # ltrim spaces
    _loc="${_loc%/}"                  # strip trailing slash
    printf '%s\n' "$_loc"
  done < "$1"
}

_bdep_sync_cfg_dirs() {
  # Print bdep configuration directories for project at $1, one per line,
  # with forward slashes (normalises Windows backslash paths from bdep output)
  # and no trailing slash (bdep config list's regular format always prints
  # one, e.g. "@gcc /path/to/cfg/ 1 target default,forwarded").
  local _line _path
  while IFS= read -r _line; do
    [[ -z "$_line" ]] && continue
    [[ "$_line" == @* ]] && _line="${_line#* }"  # strip @name prefix
    _path="${_line%% *}"                          # first field = cfg-dir path
    _path="${_path//\\//}"                        # normalise to forward slashes
    printf '%s\n' "${_path%/}"                    # strip trailing slash
  done < <(bdep config list --directory "$1" 2>/dev/null)
}

_bdep_sync_arr_idx() {
  # Print the index of value $1 within the array named $2 (bash-3.2-safe
  # indirection, no namerefs/associative arrays), or fail with no output.
  local _ref="$2[@]" _v _i=0
  for _v in "${!_ref}"; do
    [[ "$_v" == "$1" ]] && { printf '%s\n' "$_i"; return 0; }
    _i=$((_i + 1))
  done
  return 1
}

_bdep_sync_loc_diff() {
  # Compute removed/added locations between $1 (prev commit) and the current
  # packages.manifest under project root $2.  Results stored in the caller
  # variables named by $3 (removed) and $4 (added) via namerefs.
  local _prev="$1" _root="$2"
  local _removed_var="$3" _added_var="$4"
  local _prev_locs="" _curr_locs="" _loc

  while IFS= read -r _loc; do
    [[ -n "$_loc" ]] && _prev_locs+="$_loc"$'\n'
  done < <(_bdep_sync_parse_locs <(git show "$_prev:packages.manifest" 2>/dev/null))

  if [[ -f "$_root/packages.manifest" ]]; then
    while IFS= read -r _loc; do
      [[ -n "$_loc" ]] && _curr_locs+="$_loc"$'\n'
    done < <(_bdep_sync_parse_locs "$_root/packages.manifest")
  fi

  local _removed="" _added=""
  while IFS= read -r _loc; do
    [[ -n "$_loc" ]] || continue
    if ! printf '%s\n' "$_curr_locs" | grep -Fxq -- "$_loc" 2>/dev/null; then
      _removed+="$_loc"$'\n'
    fi
  done <<<"$_prev_locs"

  while IFS= read -r _loc; do
    [[ -n "$_loc" ]] || continue
    if ! printf '%s\n' "$_prev_locs" | grep -Fxq -- "$_loc" 2>/dev/null; then
      _added+="$_loc"$'\n'
    fi
  done <<<"$_curr_locs"

  printf -v "$_removed_var" '%s' "$_removed"
  printf -v "$_added_var" '%s' "$_added"
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
  local cfg loc pkg src bak="" _manifest_swapped=0 suspend _err err_out="" _ok _any _found_any _idx
  local -a cfg_dirs restored_locs=() _suspend_pkgs _suspend_locs _suspend_loc_pkgs _failed_pkgs=()

  # Skip silently during interactive rebase / git-am. git manipulates HEAD
  # rapidly and bdep sync would interleave with the in-progress operation.
  # rebase-merge/rebase-apply are per-worktree state, so this must check
  # --git-dir (the worktree-specific admin dir), not --git-common-dir (the
  # dir shared across all worktrees) -- they only coincide in the main
  # worktree, and a rebase running in a linked worktree would otherwise go
  # undetected.
  local _gd
  _gd=$(git rev-parse --git-dir 2>/dev/null) || _gd=""
  [[ -d "$_gd/rebase-merge" || -d "$_gd/rebase-apply" ]] && return 0

  # Skip silently if not a bdep project.
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  [[ -d "$root/.bdep" ]] || return 0

  # Guards: skip unless this is a branch switch with actual manifest changes
  [[ "$is_branch" != "1" || "$prev_head" == "$new_head" ]] && clr_res=$clr_warn
  if [[ -z "$clr_res" ]]; then
    command -v bdep >/dev/null 2>&1 || clr_res=$clr_warn
  fi
  if [[ -z "$clr_res" ]]; then
    _bdep_sync_loc_diff "$prev_head" "$root" removed added
    [[ -z "$removed" && -z "$added" ]] && clr_res=$clr_warn
  fi

  if [[ -z "$clr_res" ]]; then
    cfg_dirs=()
    while IFS= read -r _line; do
      cfg_dirs+=("$_line")
    done < <(_bdep_sync_cfg_dirs "$root")

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
      _suspend_locs=()
      _suspend_loc_pkgs=()
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        pkg=$(_bdep_sync_pkg_name "$root/$loc/manifest")
        _any=0
        for cfg in "${cfg_dirs[@]}"; do
          [[ -f "$cfg/$pkg/build/bootstrap/src-root.build" ]] && { _any=1; break; }
        done
        [[ $_any -eq 0 ]] && continue
        _suspend_pkgs+=("$pkg")
        _suspend_locs+=("$loc")
        _suspend_loc_pkgs+=("$pkg")
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
          # Any other failure is hard: skip bpkg+filesystem cleanup for all,
          # and keep their sources out of the git-restored-tree cleanup below
          # since bdep/bpkg may still consider them initialized here.
          if [[ "$_err" != *"not initialized in"* ]]; then
            err_out+="[bdep deinit]: $_err"$'\n'
            clr_res=$clr_err
            _failed_pkgs+=("${_suspend_pkgs[@]}")
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

          # Check bpkg state once.  --all: a collaterally-disfigured kept
          # dependent (below) may not be a held package, and must still be
          # visible here or its src-root.build could never be restored.
          # State/content are kept in parallel arrays (name[i] <-> state[i]
          # / content[i]), reset fresh every cfg iteration, rather than
          # building bash variable names out of package names: package names
          # legally contain '-', '.', '+' (none valid in a bash identifier),
          # which silently broke that scheme for exactly the hyphenated
          # names the build2 naming guide recommends.
          local -a _bp_names=() _bp_states=()
          local _line _pname _bpkg_failed_str="" _suspended_list=" ${_cfg_pkgs[*]} "
          while IFS= read -r _line; do
            _pname="${_line#!}"; _pname="${_pname%% *}"
            [[ -z "$_pname" ]] && continue
            _bp_names+=("$_pname")
            if   [[ "$_line" == *configured* ]]; then _bp_states+=("configured")
            elif [[ "$_line" == *unpacked*   ]]; then _bp_states+=("unpacked")
            elif [[ "$_line" == *broken*     ]]; then _bp_states+=("broken")
            else                                      _bp_states+=("")
            fi
          done < <(bpkg pkg-status --all --directory "$cfg" 2>/dev/null)

          # Save src-root.build content for all known packages and mark
          # which are being suspended.
          local -a _srb_names=() _srb_content=()
          for _pname in "${_bp_names[@]}"; do
            src="$cfg/$_pname/build/bootstrap/src-root.build"
            [[ -f "$src" ]] && { _srb_names+=("$_pname"); _srb_content+=("$(<"$src")"); }
          done
          for pkg in "${_cfg_pkgs[@]}"; do
            _bdep_sync_arr_idx "$pkg" _srb_names >/dev/null && continue
            src="$cfg/$pkg/build/bootstrap/src-root.build"
            [[ -f "$src" ]] && { _srb_names+=("$pkg"); _srb_content+=("$(<"$src")"); }
          done

          # Disfigure Phase: one pkg-drop call handles suspended pkgs + any kept
          # dependents; bpkg resolves the dependency order internally.
          local -a _to_disfigure=()
          local _disfigure_ok=1
          for pkg in "${_cfg_pkgs[@]}"; do
            _idx=$(_bdep_sync_arr_idx "$pkg" _bp_names) &&
              [[ "${_bp_states[$_idx]}" == configured ]] && _to_disfigure+=("$pkg")
          done
          if [[ "${#_to_disfigure[@]}" -gt 0 ]]; then
            if ! _err=$(bpkg pkg-drop --drop-dependent --disfigure-only --yes \
                          --directory "$cfg" "${_to_disfigure[@]}" 2>&1); then
              err_out+="[bpkg drop/disfigure @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err
              for pkg in "${_to_disfigure[@]}"; do
                _bpkg_failed_str="$_bpkg_failed_str $pkg "
                _failed_pkgs+=("$pkg")
              done
              _disfigure_ok=0
            fi
          fi

          # Purge Phase: only suspended packages (kept dependents stay unpacked).
          # A broken package (e.g. left over from an interrupted build) needs
          # --force to purge; without recognizing it explicitly it was
          # silently skipped here yet still got a .suspend marker below,
          # leaving it stuck registered as broken in bpkg while "suspended".
          for pkg in "${_cfg_pkgs[@]}"; do
            [[ " $_bpkg_failed_str " == *" $pkg "* ]] && continue
            _idx=$(_bdep_sync_arr_idx "$pkg" _bp_names) || continue
            local -a _purge_opts=()
            case "${_bp_states[$_idx]}" in
              configured|unpacked) ;;
              broken) _purge_opts=(--force) ;;
              *) continue ;;
            esac
            if ! _err=$(bpkg pkg-purge --directory "$cfg" "${_purge_opts[@]}" "$pkg" 2>&1); then
              err_out+="[bpkg purge $pkg @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err
              _bpkg_failed_str="$_bpkg_failed_str $pkg "
              _failed_pkgs+=("$pkg")
            fi
          done

          # Write .suspend markers for suspended packages from saved content.
          for pkg in "${_cfg_pkgs[@]}"; do
            [[ " $_bpkg_failed_str " == *" $pkg "* ]] && continue
            _idx=$(_bdep_sync_arr_idx "$pkg" _srb_names) || continue
            local srb_dir="$cfg/$pkg/build/bootstrap"
            mkdir -p "$srb_dir"
            printf '%s\n' "${_srb_content[$_idx]}" > "$srb_dir/src-root.build.suspend"
          done

          # Restore src-root.build for kept packages disfigured as dependents.
          [[ $_disfigure_ok -eq 0 ]] && continue
          for _pname in "${_bp_names[@]}"; do
            [[ " $_suspended_list " == *" $_pname "* ]] && continue
            _idx=$(_bdep_sync_arr_idx "$_pname" _srb_names) || continue
            srb_dir="$cfg/$_pname/build/bootstrap"
            mkdir -p "$srb_dir"
            printf '%s\n' "${_srb_content[$_idx]}" > "$srb_dir/src-root.build"
          done
        done
      fi

      # Never let cleanup delete a restored source whose package bdep/bpkg
      # still believes is initialized there (deinit, disfigure, or purge
      # failed for it above): that would strand it pointing at a source
      # missing build/bootstrap.build, breaking the next bdep/b update
      # ("no build/bootstrap.build in <pkg-dir>") until manually fixed.
      if [[ ${#_failed_pkgs[@]} -gt 0 ]]; then
        local -a _keep_restored=()
        local _rloc _ridx
        for _rloc in "${restored_locs[@]}"; do
          _ridx=$(_bdep_sync_arr_idx "${_rloc#"$root/"}" _suspend_locs)
          if [[ -n "$_ridx" ]] && [[ " ${_failed_pkgs[*]} " == *" ${_suspend_loc_pkgs[$_ridx]} "* ]]; then
            continue  # leave this one on disk: package still registered
          fi
          _keep_restored+=("$_rloc")
        done
        restored_locs=("${_keep_restored[@]}")
      fi

      _bdep_sync_cleanup
    fi

    # == RESUME reappearing packages ===========================================
    if [[ -n "$added" ]]; then
      # A package may have been suspended in only some of the project's
      # configurations (e.g. it was never part of every cfg to begin with).
      # bdep init applies every given package to every given configuration
      # (a full cross-product), so batching resumed packages against the
      # *union* of cfgs that held a marker for any of them would wrongly
      # initialize a package into a configuration it was never part of.
      # Group by cfg instead: one bdep init call per cfg, each scoped to
      # only the packages whose marker actually lived there.
      local -a _resume_locs=() _resume_pkgs=() _resume_logged=()
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        _resume_locs+=("$loc")
        _resume_pkgs+=("$(_bdep_sync_pkg_name "$root/$loc/manifest")")
      done <<<"$added"

      local -a _cfg_resume_dirs
      local _ri
      for cfg in "${cfg_dirs[@]}"; do
        [[ -d "$cfg" ]] || continue
        _cfg_resume_dirs=()
        for ((_ri = 0; _ri < ${#_resume_pkgs[@]}; _ri++)); do
          pkg="${_resume_pkgs[$_ri]}"
          loc="${_resume_locs[$_ri]}"
          suspend="$cfg/$pkg/build/bootstrap/src-root.build.suspend"
          [[ -f "$suspend" ]] || continue
          mv "$suspend" "${suspend%.suspend}"
          _cfg_resume_dirs+=( "-d" "$root/$loc" )
          if [[ " ${_resume_logged[*]} " != *" $pkg "* ]]; then
            printf 'initializing package %s\n' "$pkg"
            _resume_logged+=("$pkg")
          fi
        done
        [[ "${#_cfg_resume_dirs[@]}" -eq 0 ]] && continue
        if ! bdep init --no-sync --config "$cfg" "${_cfg_resume_dirs[@]}"; then
          clr_res=$clr_err
        fi
      done
    fi
  fi

  [[ -n "$err_out" ]] && printf '%s' "$err_out" >&2
  local res=${clr_res:+no}
  printf '[hook/%s]:%b%s%b\n' "bdep-sync" ${clr_res:-$clr_ok} ${res:-ok} $clr_def
  [[ "${clr_res:-$clr_ok}" != "$clr_err" ]]
}

_bdep_sync_hook "$@"
_bdep_sync_rc=$?
unset -f _bdep_sync_hook _bdep_sync_cleanup _bdep_sync_loc_diff _bdep_sync_parse_locs _bdep_sync_cfg_dirs _bdep_sync_pkg_name _bdep_sync_arr_idx
exit $_bdep_sync_rc
