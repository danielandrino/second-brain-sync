Run the integration suite with:

```bash
bash tests/test-hooks.sh
```

The script creates temporary Git repositories, installs the local hooks into each one, and exercises real commit and sync flows against a disposable external directory.
