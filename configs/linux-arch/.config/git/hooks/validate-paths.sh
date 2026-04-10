# Validate that ALL staged file paths are cross-platform valid + contain no whitespace.
#
# Enforced rules (via regex):
#   • No whitespace anywhere
#   • No Windows-forbidden characters: < > : " | ? * \
#   • Proper path structure (segments separated by single /, no leading/trailing/consecutive slashes)
#   • Works for hidden files/dirs (.github, .env, etc.) and Unicode
#
# requires: nothing
#
# To enable this hook, rename this file to "pre-commit" and
# place it in .git/hooks (or at your "core.hooksPath" dir).

# Bold White  1;37  White  1;0
# Bold Red    1;31  Red    0;31
# Bold Green  1;32  Green  0;32
# Bold Yellow 1;33  Yellow 0;33
clr_ok=$'\e[1;32m';clr_warn=$'\e[1;33m';clr_err=$'\e[1;31m'
clr_def=$'\e[1;0m';

mapfile -t STAGED_FILES < <(git diff --name-only --cached --diff-filter=d)

clr_res=""
if [[ ${#STAGED_FILES[@]} -eq 0 ]]; then
  clr_res=$clr_warn
else
  # Cross-platform safe path regex (no whitespace + valid structure)
  VALID_PATH_REGEX='^[^\\/:*?"<>|[:space:]]+(/[^\\/:*?"<>|[:space:]]+)*$'

  bad_files=()
  for file in "${STAGED_FILES[@]}"; do
    if [[ ! $file =~ $VALID_PATH_REGEX ]]; then
      bad_files+=("$file")
    fi
  done

  if [[ ${#bad_files[@]} -gt 0 ]]; then
    clr_res=$clr_err
    printf '[%berror%b] invalid staged paths (must be cross-platform safe, no whitespace):\n' \
      "$clr_err" "$clr_def" >&2
    for f in "${bad_files[@]}"; do
      printf '  - %s\n' "$f" >&2
    done
  fi
fi

res=${clr_res:+no}
printf '[hook/%s]:%b%s%b\n' \
  "paths" ${clr_res:-$clr_ok} ${res:-ok} $clr_def

if [[ "${clr_res:-$clr_ok}" == "$clr_err" ]]; then
  exit 1
fi
