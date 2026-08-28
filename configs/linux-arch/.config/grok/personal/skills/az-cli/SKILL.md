# IMPORTANT: Never include names, email addresses, organisation names, repository names, project names, IDs, or any other identifiable information in this file.

# Azure DevOps CLI: fetching PR details

## Prerequisites

Install `az` CLI (pick one):

- Windows: `winget install Microsoft.AzureCLI`
- macOS (Homebrew): `brew install azure-cli`
- Ubuntu/Debian: `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`
- Arch Linux (AUR): `yay -S azure-cli` (or `paru -S azure-cli`)

After install:

- Log in: `az login`
- Set defaults: `az devops configure --defaults organization=<org-url> project=<project>`

## Fetch PR threads (comments)

`az devops invoke` is required - `az repos` has no threads subcommand.

```bash
az devops invoke \
  --area git \
  --resource pullRequestThreads \
  --org "<org-url>" \
  --route-parameters project="<project>" repositoryId="<repo-uuid>" pullRequestId="<pr-id>" \
  --api-version 7.0 \
  --output json > /tmp/claude/pr_threads.json 2>/tmp/claude/pr_threads.err
```

Always redirect stderr separately. If stderr is merged into stdout the JSON file starts
with the warning text and fails to parse.

## Get repo UUID from PR

```bash
az repos pr show --id <pr-id> --output json > /tmp/claude/pr_show.json 2>&1
```

Then extract `repository.id` from the JSON.

## Print active threads with file/line context

```bash
jq -r '
  .value[]
  | select(.status == "active")
  | . as $t
  | (.threadContext.filePath // "") as $f
  | ((.threadContext.rightFileStart // .threadContext.leftFileStart // {}).line // "") as $l
  | .comments[]
  | select(.commentType == "text")
  | "[\($t.id)] file=\($f) line=\($l) | \(.author.displayName): \(.content | gsub("\r?\n"; " ") | .[0:120])"
' /tmp/claude/pr_threads.json
```

## Post a reply comment to a thread

```bash
MSG='Reply text with `code` formatting.'
tmp=$(mktemp /tmp/claude/XXXXXX.json)
jq -n --arg content "$MSG" '{"content": $content, "commentType": 1}' > "$tmp"
az devops invoke \
  --area git --resource pullRequestThreadComments \
  --org "<org-url>" \
  --route-parameters project="<project>" repositoryId="<repo-uuid>" pullRequestId="<pr-id>" threadId="<thread-id>" \
  --http-method POST --in-file "$tmp" \
  --api-version 7.0 --output none
rm -f "$tmp"
```

## Resolve (close) a thread

```bash
echo '{"status": "fixed"}' \
  | az devops invoke \
      --area git --resource pullRequestThreads \
      --org "<org-url>" \
      --route-parameters project="<project>" repositoryId="<repo-uuid>" pullRequestId="<pr-id>" threadId="<thread-id>" \
      --http-method PATCH --in-file /dev/stdin \
      --api-version 7.0 --output none
```

On Windows/MSYS2: `az` does not accept MSYS2 paths (e.g. `/tmp/...`) for `--in-file`. Use
`cygpath -m` to convert to a mixed Windows path (e.g. `C:/tmp/...`) before passing.

## Common thread statuses

- `active` - open, needs attention
- `fixed` - marked resolved by author
- `byDesign` - dismissed as intentional
- (empty string) - system/automation messages (branch updates, policy changes)
