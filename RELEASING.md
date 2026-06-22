# Releasing

This repository can build a local macOS zip with:

```sh
./scripts/package-release.sh
```

The zip is created at:

```text
dist/Codex-Sleep-Guard-macOS.zip
```

## GitHub Release

1. Make sure `main` is green.
2. Create and push a version tag:

```sh
git tag v0.1.0
git push origin main --tags
```

3. The `Release` GitHub Actions workflow builds `Codex-Sleep-Guard-macOS.zip` and attaches it to the GitHub Release.

## Manual Release Upload

If Actions is unavailable:

1. Run `./scripts/package-release.sh`.
2. Open the repository's Releases page.
3. Draft a new release.
4. Upload `dist/Codex-Sleep-Guard-macOS.zip`.
5. Mention that the build is ad-hoc signed and may need Privacy & Security approval on first launch.

