# Global instructions

- Check `<work-dir>/custom-skills/` for detailed tool information. CLI tools follow the naming convention `<tool>-cli.md` (e.g. `az-cli.md` for the `az` tool).

- Always use POSIX tools (assume cygwin/msys2 on Windows).
- Never add `Co-Authored-By` to commit messages.
- Only use keyboard-available characters in all written language, docs, and comments (no emojis or Unicode ornaments).
- Always match the repository's natural commit message language, layout, and style for any new commits.
- Always use `/tmp/claude/` as the base path for any temporary files (e.g. debug scripts, scratch files). Never write temp files directly into a project directory.
- Never push changes to any remote. Never modify or delete remote-tracking refs (`refs/remotes/`). Only ever work on local branches and commits. This includes never running `git push`, `git push --tags`, or any operation that writes to or rewrites remote-tracking state.
- Never split sentences with a semicolon in written language, docs, or comments. Use a comma, a full stop, or rewrite the sentence instead.
