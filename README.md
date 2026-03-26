# Second Brain Sync

Bidirectional sync between your second brain and your git repo — so AI coding agents get full context.

## The problem

AI coding agents (Claude Code, Cursor, Codex, Copilot) can read your code. They can't read your strategy docs, product decisions, competitive research, or anything else you keep in tools like Obsidian, Notion, or Apple Notes.

You end up repeating context in every prompt. The AI guesses what it doesn't know. You correct it. Repeat.

## The solution

Keep an `internal/` folder in your git repo with your strategy docs. Sync it bidirectionally with your second brain using git hooks.

```
your-project/
├── internal/           # Your private docs — strategy, research, decisions
│   ├── INDEX.md        # One-line description of every file (AI reads this first)
│   ├── product/
│   ├── strategy/
│   └── marketing/
├── app/                # Your code (or wherever your code lives)
└── AGENTS.md           # Tells AI agents where to find what
```

The AI agent opens your project, reads `AGENTS.md`, finds `internal/INDEX.md`, and knows exactly which doc to read for context. No extra prompting.

## Install

The easiest way: point your AI coding agent at this repo and ask it to set it up.

> Install second-brain-sync from https://github.com/danielandrino/second-brain-sync in my project. My external docs folder is /path/to/my/folder.

The AI will copy the hooks, set the path, and make them executable.

### Manual install

1. Copy the hooks into your project:

```bash
cp hooks/pre-commit /path/to/your/project/.git/hooks/pre-commit
cp hooks/post-commit /path/to/your/project/.git/hooks/post-commit
```

2. Make them executable:

```bash
chmod +x /path/to/your/project/.git/hooks/pre-commit
chmod +x /path/to/your/project/.git/hooks/post-commit
```

3. Set the path to your external folder (pick one):

```bash
# Option A: environment variable (in ~/.zshrc or ~/.bashrc)
export SECOND_BRAIN_DIR="/path/to/your/external/folder"

# Option B: hardcode the path directly in both hook files (replace the EXTERNAL_DIR line)
```

### Examples

```bash
# Obsidian (iCloud)
export SECOND_BRAIN_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault/Projects/MyProject"

# Obsidian (local vault)
export SECOND_BRAIN_DIR="$HOME/Documents/ObsidianVault/Projects/MyProject"

# Any synced folder (Dropbox, Google Drive, etc.)
export SECOND_BRAIN_DIR="$HOME/Dropbox/notes/my-project"
```

## How the sync works

Two git hooks handle everything. They sync **all regular files** under `internal/` and your external folder, **except** ignored paths (see below).

**Pre-commit** — runs before every commit:

- Compares each synced file in `internal/` with its copy in your second brain
- If only the external copy changed → pulls it into the project automatically
- If only the project copy changed → does nothing (post-commit handles project → external)
- If both changed and the file is **text** (no NUL byte in the first 8KB, same idea as Git’s binary detection) → 3-way merge with `git merge-file` when possible
- If both changed and the file is **binary** → commit is **aborted**; you copy one version over the other, stage, and commit again
- If both changed on the same lines (text) → commit aborted with conflict markers in the file
- If syncing or merging would overwrite **unstaged** changes in `internal/` → commit is **aborted**; stage or stash those changes first
- If there is **no committed base** (e.g. never committed, or gitignored) and internal and external **both** differ → commit is **aborted** until you pick a side

**Post-commit** — runs after every commit:

- If any path under `internal/` was part of the commit, mirrors `internal/` → external folder (`rsync` when available), **respecting the same exclusions** as pre-commit

The last committed version (HEAD) is always the merge base for files that exist in Git history. No snapshots, no databases, no daemons.

### Excluded paths (both hooks)

These are skipped and not deleted by post-commit’s mirror:

- `.obsidian/` (Obsidian config)
- `.trash/`
- `.DS_Store`
- `*.tmp`

Edit the `find` / `rsync` exclusions in **both** [hooks/pre-commit](hooks/pre-commit) and [hooks/post-commit](hooks/post-commit) together if you change them.

## The AGENTS.md + INDEX.md pattern

For AI agents to find your docs, add two files:

**AGENTS.md** (project root) — a universal standard supported by Claude Code, Cursor, Codex, Copilot, and many other tools:

```markdown
# My Project

## Project structure
- `internal/` — private docs. Read INDEX.md first.
- `app/` — application code

## Key rules
- When creating, renaming, or deleting files in internal/, update INDEX.md.
```

**internal/INDEX.md** — one-line description of every file:

```markdown
# Internal docs index

> When you create, rename, move, or delete any file in internal/, update this index.

## product/
- **product-context.md** — What we're building, why, value pillars, persona
- **strategic-decisions.md** — Architecture, licensing, stack decisions

## marketing/
- **landing-page.md** — Landing page copy and layout
- **tone-of-voice.md** — Voice guidelines for external communication
```

The AI reads INDEX.md and knows exactly which file to open — no guessing, no searching.

## How it handles edge cases

| Scenario | What happens |
|----------|-------------|
| Only external changed | Auto-synced to project, staged for commit |
| Only project changed | Post-commit copies to external |
| Both changed (text), mergeable | 3-way merge; if clean, staged |
| Both changed (text), conflict | Commit aborted; conflict markers in file |
| Both changed (binary) | Commit aborted; choose one file manually |
| Unstaged local changes would be overwritten | Commit aborted; stage or stash first |
| No HEAD base, internal and external differ | Commit aborted; pick one side, stage, commit |
| File deleted externally | Deleted in project, staged |
| File deleted in project | Post-commit removes it from external (if mirrored) |
| New file in external only | Copied to project, staged |
| External folder missing | Hooks skip silently (pre-commit warns if `SECOND_BRAIN_DIR` unset) |

## Requirements

- Git
- Bash
- `md5` (macOS) or `md5sum` (Linux)
- `rsync` (recommended for post-commit; without it, a `find`/`cp` fallback runs)

## Tests

Run the integration suite with:

```bash
bash tests/test-hooks.sh
```

It exercises real temporary Git repositories and covers text merges, binary sync/conflicts, root-commit mirroring, protection against unstaged local changes, and post-commit deletion mirroring.

## Limitations

- **Text vs binary** is inferred (NUL in the first 8KB ⇒ binary). UTF-16 and unusual encodings may be misclassified.
- **Merge** does not validate languages (e.g. merged JS may be invalid syntax); you fix that after resolving conflicts.
- The pre-commit hook works from the **staged** version of files in `internal/`. If your worktree has extra unstaged edits that would be overwritten by sync, the hook aborts instead of guessing.
- Files under `internal/` that are **gitignored** have no `HEAD` version; if internal and external both differ, the hook **aborts** instead of guessing.
- The `internal/` folder name is hardcoded. Edit the hooks if you use a different name.
- Hooks run on commit, not in real-time. Edits in your second brain are synced when you next commit.
- Point `SECOND_BRAIN_DIR` at a **dedicated** folder — never `/` or your home directory (hooks refuse those paths). Keep backups; cloud sync and partial failures can still cause surprises.

## License

MIT

## Author

Built by [Daniel Andrino](https://github.com/danielandrino). You can also find me on [X](https://x.com/andrino_daniel).
