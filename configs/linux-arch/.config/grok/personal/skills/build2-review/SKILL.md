---
name: build2-review
description: >
  Pre-release/publish sanity check for a build2 third-party package (initial
  submission, new version, or new revision) on the local or specified
  repository. Runs the packaging review checklist against the repository and
  reports findings. Read-only: makes no changes, local or externally
  visible (no commits, no pushes, no GitHub issues/PRs/comments, no email).
  Use when the user wants to sanity-check packaging before publishing, run
  the packaging review checklist locally, or runs /build2-review or
  /build2 review. Do not use for ordinary source-code review of a build2
  project (that is /review). Do not use for creating the package (that is
  build2-package). Do not use to act as an official cppget.org reviewer
  performing the actual GitHub review (that requires opening an issue/PR,
  merging, and emailing review@cppget.org, which is out of scope here).
when-to-use: >
  Triggers on "/build2-review", "/build2 review", "sanity check this build2
  package", "check packaging before publish", "run the packaging review
  checklist locally".
argument-hint: "[initial | version | revision] [<repo-or-local-path> [<version>]]"
metadata:
  short-description: "Local pre-publish build2 packaging sanity check (no external changes)"
  user-invocable: true
---

# build2-review

This is a **read-only, local sanity check**. It exists to catch packaging
problems before you publish, by running the same checklist a cppget.org
reviewer would use against the repository. It must never create, comment
on, or merge a GitHub issue or pull request, never push a branch, never
send email, and never modify the repository under review (no commits, no
tags, no file edits, no `bdep release`, no `bdep publish`, no `git push`).
If a step below would make such a change, skip it and turn it into a
reported finding instead. The repository under review must come out of
this check exactly as it went in.

The checklist and criteria in
[packaging-guide-review.md](../build2/guides/packaging-guide-review.md)
are the source of truth. Copy the checklist items. Do not paraphrase the
required criteria. Do not invent review criteria.

Reviews cover build and packaging support only. Ignore upstream source
quality, upstream docs, and style of upstream C/C++.

## Resolve ROOT

Let `HERE` be the directory that contains this `SKILL.md` (absolute path
from the system context). Let `ROOT` be `HERE/../build2`
(the existing `build2` skill). Confirm
`ROOT/guides/packaging-guide-review.md` exists. If it does not, stop.

All later `read_file` paths are `${ROOT}/...`.

## Hard rules

1. No externally visible changes: never create, comment on, or merge a
   GitHub issue or pull request, never push a branch, never send email.
2. No changes to the repository under review: no commits, tags, or file
   edits, no `git push`, no `bdep release`, no `bdep publish`. Inspection
   only (`git log`, `git show`, `git diff`, reading files). If you build or
   test something to verify an item, do it out-of-tree in a scratch
   directory, never inside the reviewed repository's working tree.
3. If given a local path, use it in place, read-only. Do not check out a
   different ref, stash, or reset it.
4. If given a remote repo or URL, clone it read-only into a scratch
   directory under `/tmp/claude/`. Never use push-capable remotes or
   `git push`. Treat the clone as disposable.
5. Never tick a checklist item without personally verifying it on this
   run.
6. Blocking vs non-blocking follows the guide's criteria. When in doubt,
   say so rather than silently downgrading a conceptual `buildfile` error.
7. The output is a report in the conversation (optionally also written to
   a scratch file under `/tmp/claude/`). Never post it anywhere external.

## Mandatory reads (before reporting findings)

Read these files in full with `read_file` before reporting any findings.
Do not skim.

1. `${ROOT}/guides/packaging-guide-review.md`
2. `${ROOT}/guides/packaging-guide-antipatterns.md`
3. `${ROOT}/HOWTO/package-naming.md`

Load on demand from the map at the end. The Initial Review Checklist
inside packaging-guide-review.md is the checklist you work through. That
file is the only copy.

## Arguments

`$ARGUMENTS` is the text after `/build2-review` (or after `/build2 review`).
Parse in order. The first matching rule wins.

| First token | Kind |
|-------------|------|
| empty / omitted | auto-detect after resolving the target |
| `initial` | full initial-submission checklist |
| `version` | new upstream version, diff-based |
| `revision` | new packaging revision, diff-based plus extra checks |
| anything else | treat as `<repo-or-local-path>` and auto-detect kind |

Remaining tokens: `<repo-or-local-path>` (GitHub URL, `owner/repo`, or a
local clone path) and optional `<version>`. If the target is missing, ask.

Report the chosen kind and version to the user before starting.

## Get the repository

If the user gave a local path, use it as-is, read-only.

Otherwise clone read-only into a scratch directory (never push to this
clone, never add it as a push target for anything else):

```
git clone --recurse-submodules --shallow-submodules <url> /tmp/claude/<name>
```

## Classify

Determine `<VERSION>` from the `manifest` `version:` field (the latest
released tag if there are several packages). Determine kind:

| Evidence | Kind |
|----------|------|
| No released tag yet, or the reviewed ref is still the first `bdep new` commit | `initial` |
| A `vX.Y.Z` tag already exists and this version is `X.Y.Z+R` | `revision` |
| A previous version was tagged and this is a new `X.Y.Z` | `version` |

Verify the first commit of the repository (read-only):

```
git log -p "$(git rev-list --all | tail -1)"
```

That commit must contain only files generated by `bdep new`, and its
message must be the exact command line. Record any deviation as a finding.
Do not ignore it.

## Kind: initial

Work through every item in the Initial Review Checklist section of
packaging-guide-review.md against the repository. Tick an item only after
personally verifying it (tree, `manifest`, `buildfile`s, install layout,
tests, tags). Use the linked HOWTO/guide for each item rather than memory.

Classify each finding exactly as the guide does:

| Class | When |
|-------|------|
| Blocking | high severity or impact, many users, conceptual error (wrong compile options in `buildfile`s), or cannot be fixed later without breaking compatibility |
| Non-blocking | should be fixed in a revision or the next version, does not fail the check |
| Note | observation only |

Load on demand while checking:

- names: `${ROOT}/HOWTO/package-naming.md`
- license: `${ROOT}/guides/packaging-license.md`
- accompanying `-tests` summary / README: `${ROOT}/HOWTO/tests-extra-dependencies.md`
- private headers: `${ROOT}/HOWTO/third-party-private-headers.md`
- compile options: `${ROOT}/HOWTO/buildfile-compile-options.md`
- what not to do: `${ROOT}/guides/packaging-guide-antipatterns.md`

### Report

Present the results to the user using the same section layout as the
guide's outcome comment, but do not post it anywhere:

```
Blocking issues:

...

Non-blocking issues:

...

Notes:

...
```

Omit empty sections. If you wrote a scratch copy, mention its path.

## Kind: version

Diff the base (previously reviewed) version against the target version.
Prefer a local `git diff <old-tag>..<new-tag>` if both tags are available
in the clone, otherwise the GitHub compare view:

```
https://github.com/<owner>/<project>/compare/vOLD...vNEW
```

Watch build-level compatibility: renamed exported targets or config
variables are breaking even when upstream's API is stable.

Report one of:

1. **No substantial packaging changes, no issues:** say so plainly, no
   checklist needed.
2. **No substantial packaging changes, there are issues:** list them
   directly (no checklist).
3. **Substantial packaging changes:** run the full initial checklist above.

## Kind: revision

Same as `version`, plus flag it as a finding if any of these does not
hold:

- Changes are limited to bug fixes in `buildfile`s, `manifest`, and
  similar packaging files.
- Upstream source fixes are limited to critical bugs backported from
  upstream.
- Strictly backwards-compatible with the version it replaces.
- No major structural changes (source layout, exported target names,
  config variable names).

## Stop and ask

Stop rather than guess when any of these is true:

- You cannot determine the version or the kind.
- You cannot access the repository (clone fails, local path invalid).
- The first commit is not a `bdep new` commit and the user has not
  decided how to record that in the report.
- Blocking vs non-blocking is unclear for a finding that would break
  compatibility.
- The user asked to actually open the GitHub review issue/PR, merge
  something, or send the review@cppget.org email. That is a separate,
  out-of-scope workflow this skill does not perform.
- The user asked to *create* the package rather than check it (switch to
  `build2-package`).

## On-demand map

| Need | File |
|------|------|
| Checklist and criteria | [packaging-guide-review.md](../build2/guides/packaging-guide-review.md) |
| What not to do | [packaging-guide-antipatterns.md](../build2/guides/packaging-guide-antipatterns.md) |
| Names | [package-naming.md](../build2/HOWTO/package-naming.md) |
| License | [packaging-license.md](../build2/guides/packaging-license.md) |
| Accompanying packages | [tests-extra-dependencies.md](../build2/HOWTO/tests-extra-dependencies.md) |
| Creating the package | [../build2-package/SKILL.md](../build2-package/SKILL.md) |
