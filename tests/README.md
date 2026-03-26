Run the integration suite with:

```bash
bash tests/test-hooks.sh
```

The script creates temporary Git repositories, installs the local hooks into each one, and exercises real commit and sync flows against a disposable external directory.

It currently covers text merges, binary sync/conflict behavior, root-commit mirroring, protection against unstaged local changes, and post-commit deletion mirroring.
