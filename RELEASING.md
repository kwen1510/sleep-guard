# Packaging

This repository can build a local macOS zip with:

```sh
./scripts/package-release.sh
```

The zip is created at:

```text
dist/Codex-Sleep-Guard-macOS.zip
```

## GitHub Release Upload

1. Run `./scripts/package-release.sh`.
2. Open the repository's Releases page.
3. Draft a new release.
4. Upload `dist/Codex-Sleep-Guard-macOS.zip`.
5. Mention that the build is ad-hoc signed and may need Privacy & Security approval on first launch.
