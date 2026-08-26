---
name: init-skills-submodules
description: >
  Initialize and update git submodules that live in the grok skills
  directory when they are missing, empty, or not checked out at the
  recorded commit. Use automatically at session start, whenever a skill
  path there is empty, and before using a skill stored as a git
  submodule, including build2.
---

# Init skills submodules

Skills in git submodules under the grok skills directory are unavailable
until those submodules are initialized and checked out.

## Steps

1. Let `<skill-dir>` be the directory that contains this file.
2. Let `<skills-dir>` be the parent of `<skill-dir>` (the grok skills
   directory that holds git submodules).
3. Let `<repo>` be the git top-level that owns it:

```sh
git -C "<skills-dir>" rev-parse --show-toplevel
```

4. Read submodule status limited to that directory:

```sh
git -C "<repo>" submodule status -- "<skills-dir>"
```

5. If there are no submodules at this path, stop. If every listed submodule
   is already initialized and on the recorded commit (status line starts
   with a space), stop.
6. Otherwise initialize and update only the submodules at this path:

```sh
git -C "<repo>" submodule update --init -- "<skills-dir>"
```

Do not recurse into nested submodules. Do not update submodules outside
`<skills-dir>`. Do not push.
