---
name: build2-package
description: >
  End-to-end third-party packaging for cppget.org (new package, new upstream
  version, or packaging revision). Use when the user wants to package a
  third-party C/C++ library or executable for build2, convert CMake/Meson to
  a cppget.org submission, publish to cppget.org, or runs /build2-package
  or /build2 package. Do not use for ordinary b/bpkg/bdep project work.
  Do not use for reviewing someone else's cppget.org submission (that is
  build2-review).
when-to-use: >
  Triggers on "/build2-package", "/build2 package", "package for cppget.org",
  "third-party package", "package this library for build2".
argument-hint: "[new | new-version | revision | continue] [<upstream-url> [<tag>]]"
metadata:
  short-description: "End-to-end third-party cppget.org packaging"
user-invocable: true
---

# build2-package

This file is the procedure. The packaging guides in the `build2` skill
(`build2/guides/` and `HOWTO/`) are the source of truth for
how each step is done. Do not invent a layout, a `bdep new` invocation, a
branch name, or a publish sequence.

## Resolve ROOT

Let `HERE` be the directory that contains this `SKILL.md` (absolute path
from the system context). Let `ROOT` be `HERE/../build2`
(the existing `build2` skill). Confirm
`ROOT/guides/packaging-guide-summary.md` exists. If it does not, stop.

All later `read_file` paths are `${ROOT}/...`.

## External actions require explicit approval

This skill creates a real, publicly visible package and eventually
publishes it. Nothing that becomes visible outside your own local working
tree happens automatically. That covers: creating a repository on GitHub,
any `git push` (a branch or a tag), transferring or renaming a repository
on GitHub, opening or merging a pull request, running `bdep ci`, and
running `bdep publish`.

Running `/build2-package` (or `/build2 package`) is not approval for any
of these, and neither is reaching the gate where one of them happens.
Before performing one of them for the first time in this run, stop, state
exactly what is about to happen (the command, and what it makes visible
externally), and wait for the user's explicit go-ahead for that specific
action. Approval for one such action does not carry over to a later one,
ask again each time. Default assumption: none of these happen unless the
user explicitly asks for that step.

Everything else, local commits, branch creation, editing files, local
builds and tests, cloning or fetching read-only, proceeds without asking.

## Hard rules

These are not optional. Violating any one is a failed run.

1. Never write `buildfile`s from scratch. Always start from `bdep new`.
   Do not use `${ROOT}/scripts/new-package.sh` for this workflow.
2. Never touch `main` after the first `bdep new --type empty,third-party`
   commit until the publish-time fast-forward merge of `review`.
3. Never bundle (vendor) dependencies. Unbundle them as `depends`.
4. Never put main `lib{}` / `exe{}` targets in the root `buildfile`.
5. Never make a library header-only if upstream ships a compiled mode.
6. Never skip the source-distribution recipe (`b dist`, then `configure`,
   `update`, `test`, `clean` in the unpacked archive). Green `bdep ci` is
   not enough.
7. Never lower the generated `depends: * build2` / `depends: * bpkg` lines.
8. Never guess an upstream tag, license, or public-header include scheme.
   If it is not in the tree or in a fetched page, stop and ask.
9. One git commit per logical packaging step (or a tightly related group).
   A commit whose tree is exactly one `bdep new` invocation uses that
   command line as the commit message, nothing else.
10. Do not merge `review` into `main`, do not `bdep release`, and do not
    `bdep publish` until local tests, installed-case tests, distribution
    tests, and CI are green.
11. Every directory-level symlink (not a plain file symlink) needs a
    matching `symlink=dir` entry in that package's own
    `<pkg>/.gitattributes` (a new file, `bdep new --package` does not
    generate one), in the same commit that adds the symlink. Verify with
    `find <pkg>/ -type l -exec test -d {} \; -print` and cross-check every
    hit against `<pkg>/.gitattributes`. `git` does not record symlink type
    and always recreates a file symlink on checkout, so skipping this
    breaks the package on a Windows checkout.
12. Never leave a comment or README note that narrates the packaging
    process itself, an earlier approach that did not work, or a mishap
    along the way. Comments and READMEs reflect only the final state (see
    packaging-guide-antipatterns.md, "Don't leave diary-style comments or
    notes").
13. Never create a repository, push, transfer or rename a repository on
    GitHub, open or merge a pull request, run `bdep ci`, or run
    `bdep publish` without the user's explicit approval for that specific
    action, given at the time (see "External actions require explicit
    approval" above). The default is that none of these happen.

## Mandatory reads (this turn, before any write)

Read these files in full with `read_file` before creating a repository,
editing a `buildfile`, or publishing. Do not skim.

1. `${ROOT}/guides/packaging-guide-summary.md`
2. `${ROOT}/guides/packaging-guide-testing.md`
3. `${ROOT}/guides/packaging-guide-antipatterns.md`
4. `${ROOT}/HOWTO/package-naming.md`

Then load on demand from the map at the end of this file. Never substitute
memory for a guide that this file names.

## Re-verify against the checklist docs as you go

A full packaging stretch (Gates A-K, or a `new-version`/`revision` run)
can span far more turns than a single context window holds. Earlier
turns, including the mandatory reads above, may already be summarized
away by the time you reach a later gate. Having read a guide once at
the start does not mean its rules are still in context, do not rely on
conversation memory for them.

Re-open and re-check the current state of the tree against these
checklist-style docs at least once per gate, and again right before
Gate K (publish-time):

- `${ROOT}/guides/packaging-guide-antipatterns.md`: what not to do
  (hand-written buildfiles, fixing upstream in the package, changed
  upstream layout, header-only despite a compiled mode, bundled
  dependencies, main targets in the root buildfile, an over-broad
  revision, bad header inclusion, ad hoc patching, diary-style comments
  or notes).
- `${ROOT}/guides/packaging-guide-review.md`: the same checklist a
  cppget.org reviewer applies. Self-check the tree against it before
  publish rather than finding out during the actual review.
- `${ROOT}/HOWTO/third-party-private-headers.md`: private headers must
  not reach the install tree.
- `${ROOT}/HOWTO/buildfile-compile-options.md`: which compile/link
  options are local vs exported.
- `${ROOT}/HOWTO/package-naming.md`: the naming decisions made at
  Gate E, a rename discovered late is expensive.
- `${ROOT}/guides/packaging-guide-summary.md` Step 5: every directory
  symlink in every package has a `symlink=dir` entry in that package's
  own `<pkg>/.gitattributes` (Hard rule 11).

If the tree no longer matches one of these, fix it before moving to the
next gate rather than carrying the drift forward.

## Arguments

`$ARGUMENTS` is the invocation text after `/build2-package` (or after
`/build2 package`). Parse it in order. The first matching rule wins.

| First token | Mode |
|-------------|------|
| empty / omitted | `new` if cwd is not already a packaging repo, else `continue` |
| `new` | initial packaging stretch |
| `new-version` | new upstream version after the first publish |
| `revision` | packaging revision (`X.Y.Z+R`) |
| `continue` | resume the in-progress stretch in cwd |
| anything else | if it looks like a git URL or `owner/repo`, treat as `new` with that upstream. Otherwise ask. |

Remaining tokens: optional `<upstream-url>` and optional `<tag-or-version>`.
If either is missing and required for the mode, ask. Do not invent them.

Report the chosen mode to the user before the first write.

## Mode: continue

Inspect cwd (and its git history) and resume at the first incomplete gate
in the matching mode below. Evidence beats conversation summary.

| Evidence | Resume at |
|----------|-----------|
| No `.git`, or no `bdep new --type empty,third-party` first commit | `new` from the start |
| First commit exists, no `review` branch | create `review` and continue `new` |
| On `review`, no `upstream/` submodule | add upstream |
| `upstream/` present, no package directory / no `bdep new --package` | package structure |
| Package scaffold present, tests or CI not green | testing |
| Tests green, `review` not merged to `main` | publish-time merge |
| On `main` after merge, no `vX.Y.Z` tag | release then publish |
| Already published, user asked for a new upstream | `new-version` |
| Already published, user asked for a packaging fix | `revision` |

If the repo is on `main` with packaging commits that should have been on
`review`, stop. That is a process error. Do not rewrite published history.
Ask the user how to recover.

## Mode: new (initial stretch)

Follow the checklist in
[packaging-guide-summary.md](../build2/guides/packaging-guide-summary.md)
and steps 8-10 in
[packaging-guide-testing.md](../build2/guides/packaging-guide-testing.md).
The numbered gates below are the ones that must not be skipped or reordered.

### Gate A: existing work

Search all four, in this order, and report the hits:

1. `https://cppget.org/?advanced-search`
2. `https://queue.cppget.org`
3. `https://github.com/build2-packaging`
4. `https://github.com/build2-packaging/WISHLIST`

If a repository or published package already exists, stop and ask whether
to join that work (`continue` / `new-version` / `revision`) instead of
starting a duplicate.

### Gate B: empty repository and first commit

**Stop and get explicit approval before this gate's external actions:**
creating the GitHub repository and pushing the initial commit to it. Do
the local scaffold (`bdep new`, `git add`, `git commit`) first if that
helps show what is about to be pushed, but do not create the remote
repository or run `git push` until the user has said to go ahead.

Create an empty public git repository in the user's personal workspace.
Description: `build2 package for <name>`. Clone with SSH. No README, no
license, no GitHub-generated files.

```
bdep new --type empty,third-party
git add .
git commit -m "bdep new --type empty,third-party"
git push -u origin main
```

Verify before continuing:

- `git rev-list --max-parents=0 HEAD` is this commit.
- `git show --stat --format=%s HEAD` message is exactly
  `bdep new --type empty,third-party`.
- The tree is only files generated by that command.

If any extra file or hand edit is in that commit, reset and redo. The
review process depends on this.

### Gate C: review branch

```
git checkout -b review
```

Stay on `review` for every later commit in this stretch. Do not
`git checkout main`. Do not merge. Do not release. Do not publish.

### Gate D: upstream submodule

```
git submodule add https://github.com/<upstream>/<repo>.git upstream
```

Use `https://` only. Checkout the release commit (tag). Commit:
`Add upstream submodule, <tag>`.

### Gate E: names and layout

Read `${ROOT}/HOWTO/package-naming.md` again if needed. Decide, and write
the decisions down before generating the package:

- Git repository name: upstream case, no `build2-` prefix, no `-package`
  suffix.
- `project:` and `project =`: lowercase unless mixed case is the upstream
  identifier (Qt is the documented exception).
- Package `name:`: `lib` prefix for libraries unless both Debian and
  upstream make an executable clash impossible.
- Split library vs executable into separate packages.
- Public-header include scheme (subdirectory prefix vs filename prefix).
- Combined vs split `include/` / `src/`.

Stay as close to upstream layout as possible.

### Gate F: pre-seed then `bdep new --package`

Create the package directory. Symlink only the upstream meta files that
exist (`README.md`, `LICENSE` / equivalent, `NEWS` / `CHANGES` /
`ChangeLog`). Commit that alone. Then:

```
bdep new --package --lang ... --type lib,...,third-party <name>
```

Iterate by deleting and re-running, not by hand-editing the scaffold, until
the layout matches. The `third-party` sub-option is required. Commit with
the exact command line as the message.

If the changelog basename is not a recognized name, set `changes-file:`
by hand later. See `${ROOT}/HOWTO/package-changes-file.md`.

### Gate G: version, manifest, dependencies

- Version stays `X.Y.Z-a.0.z` until `bdep release --no-open`.
- `summary`: under 70 characters, no weasel words, no trailing period.
- Accompanying `-tests` / `-examples` / `-benchmarks`: copy the main
  summary and append ` (tests)` (or the matching kind). Do not rewrite it.
  See `${ROOT}/HOWTO/tests-extra-dependencies.md`.
- `license:` is SPDX (or `other:`). See `${ROOT}/guides/packaging-license.md`.
- Uncomment the `pkg.cppget.org` prerequisite. Use the least-stable section
  that still contains every dependency. Do not leave `queue.cppget.org` in
  a long-lived `repositories.manifest`.
- `bdep sync -a` after `depends` edits.
- Interface headers in this library's public headers go in `intf_libs`.
  Everything else goes in `impl_libs`.

### Gate H: fill source and buildfiles

Fill the package tree with upstream source before touching buildfiles:
symlink individual header/source files first, and symlink a whole
subdirectory only when that saves many individual symlinks (requires the
`buildfile-in-prefix` layout, see packaging-guide-antipatterns.md). Follow
the worked example in
`${ROOT}/guides/packaging-guide-summary.md` Step 5.

**Mandatory:** for every directory symlink just added, add a matching
`symlink=dir` entry to that package's own `<pkg>/.gitattributes` (create
the file if it does not exist yet) in the same commit. Verify with
`find <pkg>/ -type l -exec test -d {} \; -print` and cross-check every hit.
This is Hard rule 11, skipping it breaks the package on a Windows checkout.
Commit the symlinks (and `.gitattributes`) before adjusting buildfiles, so
rollback is easy.

Then adjust generated files only. Preserve generated structure and comments.

Load on demand:

- headers / private headers: `${ROOT}/HOWTO/third-party-private-headers.md`
- SONAME / output name: `${ROOT}/HOWTO/match-upstream-library-name.md`
- compile options: `${ROOT}/HOWTO/buildfile-compile-options.md`
- system libs: `${ROOT}/HOWTO/link-system-library.md`
- pthread: `${ROOT}/HOWTO/link-pthread.md`
- feature `require`: `${ROOT}/HOWTO/require-dependency-feature.md`

Verify a throwaway install:

```
b install config.install.root=/tmp/install
```

Public headers must land in a library subdirectory (or include the library
name in the filename). No private headers in the install tree.

### Gate I: tests

A library needs at least one test to be publishable.

1. Smoke test under `tests/basics/`: include the public header, call at
   least one non-inline function.
2. Local: `bdep update` and `bdep test -a`.
3. Installed case: the recipe in packaging-guide-testing.md Step 9.
4. Source distribution, including `b clean` in the unpacked archive.
5. Commit on `review`. Then stop and get explicit approval before
   `git push -u origin review` and before `bdep ci`, these are two
   separate external actions (a push, and a CI queue submission). Once
   approved and run, wait until no configuration is `<unbuilt>` or
   `building`.
6. Only then replace the smoke test with upstream tests (if applicable).
   Extra test-only dependencies belong in a sibling `-tests` package.

Unsupported platforms go in `builds:` / `build-include:` /
`build-exclude:`, not as ignored CI red. See
`${ROOT}/HOWTO/builds-ci-filtering.md`.

### Gate J: READMEs

Keep `PACKAGE-README.md` on the generated template. Fill `<...>`
placeholders. Do not add sections. Accompanying packages use the short
template in packaging-guide-testing.md, not the Usage-style template.

Adjust repository `README.md`.

### Gate K: publish-time only

Do this only after Gates I and J are green. Every numbered step from 2
onward is an external action and needs its own explicit approval, given
right before that step, not assumed from having reached this gate.

1. Fast-forward `review` into `main` (`git merge --ff-only review`). If
   that fails, stop. `main` should still be the first `bdep new` commit.
   This step is local, no approval needed.
2. Stop, get explicit approval, then transfer the repository to
   `github.com/build2-packaging` before the first publish (GitHub
   Settings, Danger Zone, Transfer). Rename first if the name still has a
   `build2-` prefix or `-package` suffix. If you transferred while still
   on `review`, merge through a pull request (`base: main`,
   `compare: review`) because `main` is protected on that org, opening
   and merging that PR is its own external action and needs its own
   approval too.
3. Stop, get explicit approval, then from `main`:
   `bdep release --no-open --show-push`, review the commit, push the tag.
4. Stop, get explicit approval, then `bdep publish`. Review the queue
   build. Do not pass `--section=stable` unless the version would
   otherwise land in the wrong section (zero major that upstream does not
   treat as alpha).

After the first submission, the package waits in `testing` for a
`build2-review`. That review is a different skill.

## Mode: new-version

Read `${ROOT}/guides/packaging-guide-version-management.md` in full before
any write. Do not use a branch named `review` (that name is reserved for
the initial stretch).

1. `git checkout -b wip-X.Y.Z`
2. `bdep release --open --no-push --open-base X.Y.Z`
3. Update `upstream/` to the new release tag. Commit that alone.
4. Review the upstream diff (`gitk` or `git diff vOLD..vNEW` inside
   `upstream/`) for layout, dependencies, source files, and build-system
   changes.
5. Re-apply any `.orig` / `.patch` overlays. See antipatterns.
6. Adjust symlinks and `buildfile`s (update `.gitattributes` for any new
   or changed directory symlinks, see Hard rule 11). Review `manifest`
   and both READMEs.
7. Repeat Gate I (local, installed, dist including `clean`, CI), the same
   explicit-approval requirement applies to its push and `bdep ci` step.
8. Fast-forward merge `wip-X.Y.Z` into `main` if you are the maintainer
   (local, no approval needed), or, with explicit approval, open a PR if
   you are not.
9. Stop, get explicit approval, then `bdep release --no-open --show-push`,
   then, with a separate explicit approval, `bdep publish`.

A from-scratch rewrite of upstream may mean deleting the package directory
and repeating Gate F on this branch.

## Mode: revision

Read `${ROOT}/guides/packaging-guide-version-management.md` (New Revision)
in full.

Allowed changes: bug fixes in `buildfile`s / `manifest` / packaging
infrastructure, plus critical upstream bugs backported from upstream.
No exported-target renames, no config-variable renames, no layout
rewrites.

The revision release is one squashed commit (`bdep release --revision`,
with `--amend --squash N` if the work was developed as several commits).
Test locally first, then, with explicit approval for the push and
`bdep ci`, test with CI, and only then, with a separate explicit
approval, `bdep publish`.

## Stop and ask

Stop rather than guess when any of these is true:

- Upstream has no tagged release.
- Public headers use unqualified names like `<util.h>` (read
  antipatterns, "Bad Header Inclusion Practice", before continuing).
- A compiled mode does not work on a required platform.
- `git merge --ff-only review` fails.
- Dist-archive `b clean` fails while `bdep test` is green.
- The user asked only for a review of an existing submission
  (switch to `build2-review`).

## On-demand map

| Need | File |
|------|------|
| Concepts, review branch, steps 1-7 | [packaging-guide-summary.md](../build2/guides/packaging-guide-summary.md) |
| Tests, CI, merge, publish | [packaging-guide-testing.md](../build2/guides/packaging-guide-testing.md) |
| What not to do, patching | [packaging-guide-antipatterns.md](../build2/guides/packaging-guide-antipatterns.md) |
| New version / revision | [packaging-guide-version-management.md](../build2/guides/packaging-guide-version-management.md) |
| Repository / project / package names | [package-naming.md](../build2/HOWTO/package-naming.md) |
| License field | [packaging-license.md](../build2/guides/packaging-license.md) |
| Accompanying test packages | [tests-extra-dependencies.md](../build2/HOWTO/tests-extra-dependencies.md) |
| Version / constraint syntax | [bpkg-package-name-version.md](../build2/guides/bpkg-package-name-version.md) |
| `bdep new` layouts | [bdep-new-layouts.md](../build2/bdep/bdep-new-layouts.md) |
| Review of the result | [../build2-review/SKILL.md](../build2-review/SKILL.md) |
