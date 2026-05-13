# clang-format staged C++ files and re-add to commit.
#
# requires: clang-format, bash >=3.2
#
# To enable this hook, rename this file to "pre-commit" and
# place it in .git/hooks (or at your "core.hooksPath" dir).

# Bold White  1;37  White  1;0
# Bold Red    1;31  Red    0;31
# Bold Green  1;32  Green  0;32
# Bold Yellow 1;33  Yellow 0;33
clr_ok=$'\e[1;32m';clr_warn=$'\e[1;33m';clr_err=$'\e[1;31m'
clr_def=$'\e[1;0m';

# Skip if no clang-format exe.
if ! command -v clang-format >/dev/null 2>&1; then
  clr_res=$clr_warn
fi

# Skip if no .clang-format config.
if [[ -z "$clr_res" ]]; then
  _dir=$(git rev-parse --show-toplevel)
  while [[ -n "$_dir" ]]; do
    [[ -f "$_dir/.clang-format" || -f "$_dir/_clang-format" ]] && break
    _parent="${_dir%/*}"
    [[ "$_parent" == "$_dir" ]] && { _dir=""; break; }
    _dir="$_parent"
  done
  [[ -z "$_dir" ]] && clr_res=$clr_warn
fi

# Skip if no C/C++ changes.
if [[ -z "$clr_res" ]]; then
  STAGED_SRCS=()
  while IFS= read -r _line; do
    STAGED_SRCS+=("$_line")
  done < <(git diff --name-only --cached --diff-filter=d -- '*.[hc]' '*.cc' '*.[hc]xx' '*.[hc]pp')
  [[ ${#STAGED_SRCS[@]} -eq 0 ]] && clr_res=$clr_warn
fi

if [[ -z "$clr_res" ]]; then
  # (1) stash any unstaged changes in the staged files
  stashed=0
  if ! git diff --quiet -- "${STAGED_SRCS[@]}"; then
    git stash push --keep-index --quiet --message "[hook/fmt]" -- "${STAGED_SRCS[@]}"
    stashed=1
  fi

  # format staged files
  if ! clang-format -i --style=file -- "${STAGED_SRCS[@]}"; then
    clr_res=$clr_err
  elif ! git diff --quiet --exit-code -- "${STAGED_SRCS[@]}"; then
    # add diff interactively if a TTY is available, otherwise stage all changes
    if [[ -e /dev/tty ]]; then
      git add --patch -- "${STAGED_SRCS[@]}" </dev/tty
    else
      git add -- "${STAGED_SRCS[@]}"
    fi
  fi

  # (1) restore original unstaged changes
  [[ $stashed -eq 1 ]] && git stash pop --quiet 2>/dev/null || true
fi

res=${clr_res:+no}
printf '[hook/%s]:%b%s%b\n' \
  "fmt" ${clr_res:-$clr_ok} ${res:-ok} $clr_def

if [[ "${clr_res:-$clr_ok}" == "$clr_err" ]]; then
  exit 1
fi
