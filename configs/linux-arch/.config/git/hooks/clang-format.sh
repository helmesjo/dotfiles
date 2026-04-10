# clang-format staged C++ files and re-add to commit.
#
# requires: clang-format
#
# To enable this hook, rename this file to "pre-commit" and
# place it in .git/hooks (or at your "core.hooksPath" dir).

# Bold White  1;37  White  1;0
# Bold Red    1;31  Red    0;31
# Bold Green  1;32  Green  0;32
# Bold Yellow 1;33  Yellow 0;33
clr_ok=$'\e[1;32m';clr_warn=$'\e[1;33m';clr_err=$'\e[1;31m'
clr_def=$'\e[1;0m';

if ! command -v clang-format >/dev/null 2>&1; then
  clr_res=$clr_warn
else
  mapfile -t STAGED_SRCS < <(git diff --name-only --cached --diff-filter=d -- '*.[hc]' '*.cc' '*.[hc]xx' '*.[hc]pp')
  if [[ ${#STAGED_SRCS[@]} -eq 0 ]]; then
    clr_res=$clr_warn
  else
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
      # add diff; force stdin to come from the real terminal
      git add --patch -- "${STAGED_SRCS[@]}" </dev/tty
    fi

    # (1) restore original unstaged changes
    [[ $stashed -eq 1 ]] && git stash pop --quiet 2>/dev/null || true
  fi
fi

res=${clr_res:+no}
printf '[hook/%s]:%b%s%b\n' \
  "fmt" ${clr_res:-$clr_ok} ${res:-ok} $clr_def

if [[ "${clr_res:-$clr_ok}" == "$clr_err" ]]; then
  exit 1
fi
