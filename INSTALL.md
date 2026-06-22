# Install Codex Sleep Guard

Codex Sleep Guard is a macOS menu bar utility for keeping Codex work alive without keeping your Mac awake all the time.

## Requirements

- macOS 14 or newer
- Apple Silicon or Intel Mac
- Xcode command line tools only if you build from source

## Recommended Install

1. Open the GitHub Releases page for this repository.
2. Download `Codex-Sleep-Guard-macOS.zip`.
3. Unzip it.
4. Drag `Codex Sleep Guard.app` into `/Applications`.
5. Double-click the app.
6. If macOS blocks it because this is a local unsigned/ad-hoc build, open System Settings > Privacy & Security and allow it, or right-click the app and choose Open.

The app shows a normal window and a menu bar icon. If your menu bar is crowded, use the Dock icon to reopen the window.

## First Run

- Leave `Prevent sleep while Codex works` on for normal use.
- Turn on `Launch at Login` if you want the app to start automatically.
- Keep `Carry Mode` off unless you specifically need lid-closed operation.

## Carry Mode

Carry Mode is the high-alert mode for carrying a MacBook with the lid closed while Codex keeps working.

When enabled, the app uses a privileged helper to run:

```sh
pmset -a disablesleep 1
```

When disabled, it restores:

```sh
pmset -a disablesleep 0
```

The app asks for password or Touch ID before enabling Carry Mode. macOS may also ask you to approve `Codex Sleep Guard Power Helper` under System Settings > Login Items & Extensions.

Carry Mode turns the UI red while active. Use it temporarily, keep the Mac somewhere it can shed heat, and turn it off as soon as the task is done.

Emergency restore:

```sh
sudo pmset -a disablesleep 0
```

## Build From Source

Install XcodeGen first:

```sh
brew install xcodegen
```

Then build:

```sh
xcodegen generate
xcodebuild -project CodexSleepGuard.xcodeproj -scheme CodexSleepGuard -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

To create a local zip package:

```sh
./scripts/package-release.sh
```

The package will be written to `dist/Codex-Sleep-Guard-macOS.zip`.

