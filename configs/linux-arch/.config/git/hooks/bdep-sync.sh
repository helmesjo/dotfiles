# bdep-sync: suspend/resume bdep packages when switching git branches.
#
# REQUIRES
#   bdep, bpkg
#
# OVERVIEW
#   build2 out-tree configurations record the source root via a single marker
#   file:
#     <cfg-dir>/<pkg>/build/bootstrap/src-root.build
#   This file makes build2 treat the out-tree directory as a valid out-root.
#   When a branch is checked out that does not contain a package present on the
#   previous branch, its source directory disappears from the worktree but its
#   out-tree build artefacts and bpkg/bdep database entries remain and become
#   stale.
#
#   This hook keeps both sides in sync by saving/restoring src-root.build
#   (renamed to .suspend) and updating the bdep/bpkg databases whenever
#   packages.manifest changes between branches.
#
# INVARIANTS
#   - ALL removed package sources must be restored via `git restore` BEFORE
#     any `bdep deinit` is issued: bdep reads every location listed in
#     packages.manifest in a single pass when resolving package names.
#   - src-root.build must be present DURING `bdep deinit`: deinit on a
#     forward configuration calls `b disfigure: src@out,forward`, which
#     bootstraps the out-root via src-root.build.
#   - src-root.build is renamed to .suspend only AFTER `bdep deinit` for
#     that package completes.
#
# SCENARIOS
#
#   Condition                    Steps
#   ===========================  ==============================================
#   not a branch checkout        skip (warn)
#   same commit on both sides    skip (warn)
#   not a bdep project           skip (warn)
#   bdep not on PATH             skip (warn)
#   packages.manifest identical  skip (warn)
#   pkg removed (suspend)        git restore src; bdep deinit; bpkg disfigure;
#                                bpkg purge; mv src-root.build -> .suspend;
#                                rm restored src
#   pkg added (resume)           mv .suspend→src-root.build; bdep init --no-sync
#   both removed and added       suspend all removed (order above); then resume
#                                all added
#
# ENVIRONMENT
#   BDEP_SYNC_AUTO_CLEAN  When set, suspended source trees are removed with
#                         `rm -rf`. Default: remove only git-tracked files,
#                         leaving any untracked content (build artefacts, etc.)
#                         in place.
#

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

_bdep_sync_hook() {
  local prev_head="$1" new_head="$2" is_branch="$3"
  local clr_ok=$'\e[1;32m' clr_warn=$'\e[1;33m' clr_err=$'\e[1;31m' clr_def=$'\e[1;0m'
  local clr_res="" root="" prev_locs curr_locs removed added
  local cfg loc pkg src bak suspend resumed _err _loc _rel _f err_out=""
  local restored_locs=()

  # Guard: only act on branch switches
  [[ "$is_branch" != "1" || "$prev_head" == "$new_head" ]] && clr_res=$clr_warn

  # Guard: resolve project root
  if [[ -z "$clr_res" ]]; then
    root=$(git rev-parse --show-toplevel 2>/dev/null) || clr_res=$clr_warn
  fi

  # Guard: must be a bdep project
  if [[ -z "$clr_res" ]] && [[ ! -f "$root/packages.manifest" || ! -d "$root/.bdep" ]]; then
    clr_res=$clr_warn
  fi

  # Guard: require bdep on PATH
  if [[ -z "$clr_res" ]] && ! command -v bdep >/dev/null 2>&1; then
    clr_res=$clr_warn
  fi

  # Compute location diff between branches
  if [[ -z "$clr_res" ]]; then
    prev_locs=$(_bdep_sync_parse_locs <(git show "$prev_head:packages.manifest" 2>/dev/null))
    curr_locs=$(_bdep_sync_parse_locs "$root/packages.manifest")
    removed=$(comm -23 <(sort <<<"$prev_locs") <(sort <<<"$curr_locs"))
    added=$(comm -13   <(sort <<<"$prev_locs") <(sort <<<"$curr_locs"))
    [[ -z "$removed" && -z "$added" ]] && clr_res=$clr_warn
  fi

  if [[ -z "$clr_res" ]]; then
    local -a cfg_dirs
    mapfile -t cfg_dirs < <(_bdep_sync_cfg_dirs "$root")

    # == SUSPEND removed packages ==============================================
    if [[ -n "$removed" ]]; then
      bak="$root/packages.manifest.bdep-sync-bak"
      trap "[[ -f '$bak' ]] && mv '$bak' '$root/packages.manifest'" EXIT

      # 1. Backup new-branch manifest; 2. restore previous-branch manifest.
      cp "$root/packages.manifest" "$bak"
      git show "$prev_head:packages.manifest" > "$root/packages.manifest"

      # 3. Restore ALL removed package sources from git before any deinit.
      #    bdep load_package_names reads every location listed in packages.manifest
      #    in a single pass, so all sources must exist simultaneously.
      #    Using the real source tree (not stubs) ensures build2 can properly
      #    bootstrap all subprojects during bdep deinit on forward configurations.
      #    src-root.build must remain in the out-tree until after bdep deinit.
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        git -C "$root" restore --quiet --source="$prev_head" --worktree -- "$loc" 2>/dev/null
        restored_locs+=("$root/$loc")
      done <<<"$removed"

      # 4. Per removed pkg: deinit from bdep DB, then disfigure/purge from bpkg
      #    and save the suspend marker.  Both operations are done together per
      #    package: deinit requires src-root.build present (forward bootstrap);
      #    src-root.build is renamed to .suspend only after deinit completes.
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        pkg="${loc##*/}"
        printf 'deinitializing package %s\n' "$pkg"
        if ! bdep deinit --force --all --directory "$root" "$pkg"; then
          clr_res=$clr_err
        fi
        for cfg in "${cfg_dirs[@]}"; do
          [[ -d "$cfg" ]] || continue
          src="$cfg/$pkg/build/bootstrap/src-root.build"
          [[ -f "$src" ]] || continue
          if [[ "$(bpkg pkg-status --directory "$cfg" "$pkg" 2>/dev/null)" == *configured* ]]; then
            if ! _err=$(bpkg pkg-disfigure --directory "$cfg" --keep-out --keep-config "$pkg" 2>&1); then
              err_out+="[bpkg disfigure $pkg @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err
            elif ! _err=$(bpkg pkg-purge --directory "$cfg" "$pkg" 2>&1); then
              err_out+="[bpkg purge $pkg @ ${cfg##*/}]: $_err"$'\n'
              clr_res=$clr_err
            fi
          fi
          cp "$src" "${src}.suspend"
          rm "$src"
        done
      done <<<"$removed"

      # 5. Restore new-branch manifest; 6. remove restored source trees.
      mv "$bak" "$root/packages.manifest"
      trap - EXIT
      for _loc in "${restored_locs[@]}"; do
        _rel="${_loc#"$root/"}"
        if [[ -n "${BDEP_SYNC_AUTO_CLEAN-}" ]]; then
          rm -rf "$_loc"
        else
          # Remove only tracked files we restored; leave git-left untracked
          # content.
          while IFS= read -r _f; do
            rm -f "$root/$_f"
          done < <(git -C "$root" ls-tree -r --name-only "$prev_head" -- "$_rel" 2>/dev/null)
          find "$_loc" -depth -type d -empty -delete 2>/dev/null
        fi
      done
    fi

    # == RESUME reappearing packages ===========================================
    if [[ -n "$added" ]]; then
      while IFS= read -r loc; do
        [[ -z "$loc" ]] && continue
        pkg="${loc##*/}"
        resumed=0
        for cfg in "${cfg_dirs[@]}"; do
          [[ -d "$cfg" ]] || continue
          suspend="$cfg/$pkg/build/bootstrap/src-root.build.suspend"
          [[ -f "$suspend" ]] || continue
          mv "$suspend" "${suspend%.suspend}"
          resumed=1
        done
        [[ $resumed -eq 0 ]] && continue
        if ! bdep init --no-sync --all -d "$root/$loc"; then
          clr_res=$clr_err
        fi
      done <<<"$added"
    fi
  fi

  [[ -n "$err_out" ]] && printf '%s' "$err_out" >&2
  local res=${clr_res:+no}
  printf '[hook/%s]:%b%s%b\n' "bdep-sync" ${clr_res:-$clr_ok} ${res:-ok} $clr_def
  if [[ "${clr_res:-$clr_ok}" == "$clr_err" ]]; then
    return 1
  fi
}

_bdep_sync_hook "$@"
_bdep_sync_rc=$?
unset -f _bdep_sync_hook _bdep_sync_parse_locs _bdep_sync_cfg_dirs
exit $_bdep_sync_rc
