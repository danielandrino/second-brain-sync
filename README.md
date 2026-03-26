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

## How the sync works

Two git hooks handle everything:

**Pre-commit** — runs before every commit:
- Compares each file in `internal/` with its copy in your second brain
- If only the external copy changed → pulls it into the project automatically
- If only the project copy changed → does nothing (post-commit handles it)
- If both changed on different lines → 3-way merge using `git merge-file`, resolves automatically
- If both changed on the same lines → aborts the commit with conflict markers for you to resolve

**Post-commit** — runs after every commit:
- If any file in `internal/` was part of the commit, copies `internal/` → external folder

The last committed version (HEAD) is always the merge base. No snapshots, no databases, no daemons.

## Install

```bash
git clone https://github.com/danielandrino/second-brain-sync.git
cd second-brain-sync
./install.sh /path/to/your/project
```

Then set the `SECOND_BRAIN_DIR` environment variable to your external folder:

```bash
# In ~/.zshrc or ~/.bashrc
export SECOND_BRAIN_DIR="/path/to/your/obsidian/vault/ProjectDocs"
```

Or hardcode the path directly in `.git/hooks/pre-commit` and `.git/hooks/post-commit` (replace the `EXTERNAL_DIR` line).

## Examples

### Obsidian (iCloud)

```bash
export SECOND_BRAIN_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault/Projects/MyProject"
```

### Obsidian (local vault)

```bash
export SECOND_BRAIN_DIR="$HOME/Documents/ObsidianVault/Projects/MyProject"
```

### Any folder

```bash
export SECOND_BRAIN_DIR="$HOME/Dropbox/notes/my-project"
```

## The AGENTS.md + INDEX.md pattern

For AI agents to find your docs, add two files:

**AGENTS.md** (project root) — a universal standard supported by Claude Code, Cursor, Codex, Copilot, and 20+ tools:

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
| Both changed, different lines | 3-way merge resolves automatically |
| Both changed, same lines | Commit aborted, conflict markers in file |
| File deleted externally | Deleted in project, staged |
| File deleted in project | Post-commit removes from external |
| New file in external only | Copied to project, staged |
| External folder missing | Hooks skip silently |

## Requirements

- Git
- Bash
- `md5` (macOS) or `md5sum` (Linux)

## Limitations

- Only syncs `*.md` files. Edit the `find` command in the hooks to change this.
- The `internal/` folder name is hardcoded. Edit the hooks if you use a different name.
- Hooks run on commit, not in real-time. Edits in your second brain are synced when you next commit.

## License

MIT
