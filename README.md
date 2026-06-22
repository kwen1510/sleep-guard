# Codex Sleep Guard

## TLDR: Install It

This is a Mac app that keeps your Mac awake while Codex is working, then lets it sleep again when Codex is done.

### Easiest Way

1. Download [Codex-Sleep-Guard-macOS.zip](https://github.com/kwen1510/sleep-guard/raw/main/dist/Codex-Sleep-Guard-macOS.zip).
2. Open your `Downloads` folder.
3. Double-click the zip file to unzip it.
4. Drag `Codex Sleep Guard.app` into your `Applications` folder.
5. Open `Codex Sleep Guard.app`.
6. If macOS says it cannot verify the app, right-click the app and choose `Open`.
7. Leave `Prevent sleep while Codex works` switched on.
8. Only use `Carry Mode` if you really need the Mac to keep working with the lid closed.

### Copy This Into Codex To Install And Test It

Open Codex on your Mac and paste this:

```text
Please install and test Codex Sleep Guard from https://github.com/kwen1510/sleep-guard.

Download this zip:
https://github.com/kwen1510/sleep-guard/raw/main/dist/Codex-Sleep-Guard-macOS.zip

Do the full setup for me:
1. Download the zip to a temporary folder.
2. Unzip it.
3. Move "Codex Sleep Guard.app" to /Applications, replacing any older copy.
4. Open the app.
5. If macOS asks for approval, tell me exactly what to click.
6. Verify the app is running.
7. Verify a "Codex Sleep Guard" window appears.
8. Verify normal Guard mode is on.
9. Verify Carry Mode is off by checking that `pmset -g live` shows `SleepDisabled 0`.
10. Do not enable Carry Mode unless I explicitly ask.

When you are done, tell me either "Codex Sleep Guard is installed, tested, and ready to use" or tell me exactly what failed.
```

### What To Click After Opening

- Keep `Prevent sleep while Codex works` on.
- Turn on `Launch at Login` if you want it to start automatically.
- Leave `Carry Mode` off for normal use.
- If you turn on `Carry Mode`, approve password or Touch ID, and turn it off again as soon as possible.

Emergency reset if Carry Mode ever gets stuck:

```sh
sudo pmset -a disablesleep 0
```

## What It Does

Codex Sleep Guard is a native macOS 14+ menu bar utility that prevents user-idle system sleep only while Codex is actively executing work. When Codex returns to idle, the app keeps the assertion for a five-minute grace period, then releases it. The menu bar item includes a persistent Guard On/Off switch; when switched off, the app continues to show detection status but never holds a sleep-prevention assertion.

The app also includes Carry Mode for the specific case where you want to keep a MacBook awake with the lid closed while Codex is working. Carry Mode changes the system sleep setting through a privileged helper, requires password or Touch ID before activation, turns the UI red while enabled, and can switch itself off when Codex finishes.

## Install

Download [Codex-Sleep-Guard-macOS.zip](https://github.com/kwen1510/sleep-guard/raw/main/dist/Codex-Sleep-Guard-macOS.zip), unzip it, and drag `Codex Sleep Guard.app` into `/Applications`.

See [INSTALL.md](INSTALL.md) for first-run, helper approval, Carry Mode, and emergency recovery instructions.

## Features

- Prevents idle sleep only while Codex is actually working.
- Detects Codex activity from local Codex session telemetry and managed process data.
- Releases the sleep assertion after Codex finishes, with a five-minute grace period.
- Provides a persistent Guard On/Off switch.
- Supports Launch at Login.
- Shows diagnostics from `pmset -g assertions`.
- Includes optional Carry Mode for temporary lid-closed operation.
- Carry Mode requires password or Touch ID and turns the UI red while active.
- Carry Mode can automatically turn itself off when Codex finishes.

## Safety

Normal Guard mode uses Apple's idle-sleep assertion API and does not override lid-closed sleep. Carry Mode is different: it changes macOS's `disablesleep` setting through a privileged helper so the Mac can continue running with the lid closed.

Use Carry Mode only temporarily. Do not leave the Mac sealed in a bag where it cannot shed heat. If anything goes wrong, run:

```sh
sudo pmset -a disablesleep 0
```

That restores normal lid-closed sleep behavior.

## Architecture

- `AppState`: ObservableObject state machine for Codex activity, sleep protection, and grace-period transitions.
- `CodexActivityDetector`: pluggable detector protocol. The default composite detector uses:
  - Codex session JSONL files under `~/.codex/sessions` as the primary work/idle signal.
  - Codex process-manager data under `~/.codex/process_manager/chat_processes.json` as a conservative fallback for running Codex-managed commands.
  - Process presence only for "Codex Detected", never as proof of active work.
- `SleepManager`: wraps Apple's `IOPMAssertionCreateWithName` and `IOPMAssertionRelease` using `kIOPMAssertionTypePreventUserIdleSystemSleep`.
- `GracePeriodManager`: starts, cancels, and ticks the five-minute grace period.
- `DiagnosticsManager`: runs `pmset -g assertions` and extracts assertion owner lines for debugging.
- `CarryModeManager`: coordinates the red warning UI, per-use authentication, auto-off behavior, and recovery state for lid-closed Carry Mode.
- `CodexSleepGuardPowerHelper`: privileged launch daemon helper used only by Carry Mode to run `pmset -a disablesleep 1` and `pmset -a disablesleep 0`.

## Battery Behavior

The app itself is lightweight: it checks local Codex activity every few seconds and does not run heavy background work. Battery use mainly comes from the intentional effect of the app: while Codex is active and Guard is On, macOS is prevented from entering user-idle system sleep. Low Power Mode can still reduce performance, but it should not override an active idle-sleep assertion.

Closing a MacBook lid is different from idle sleep. Normal Guard mode does not prevent forced lid sleep, so Wi-Fi or a phone hotspot can still cut off when the lid closes.

Carry Mode is the exception. It uses a privileged helper to change macOS's `disablesleep` setting, which is the same system-level strategy used by lid-closed utilities such as Macchiato. This is intentionally treated as a temporary high-alert mode because the Mac can keep running in a bag. Use it only when needed, keep the machine where it can shed heat, and turn it off as soon as the task is done.

If Carry Mode ever appears stuck on, run:

```sh
sudo pmset -a disablesleep 0
```

That command restores normal lid-closed sleep behavior.

## Carry Mode Setup

The first time Carry Mode needs the helper, macOS may ask you to approve `Codex Sleep Guard Power Helper` in System Settings under Login Items or Background Items. After approval, try the Carry Mode switch again. Every activation still asks for password or Touch ID before changing the sleep setting.

Carry Mode controls:

- `Carry Mode`: turns lid-closed sleep prevention on or off.
- `Auto off when Codex finishes`: when enabled, Carry Mode turns itself off after it has seen Codex protected and then return to idle.
- `Open Approval Settings`: appears if macOS requires helper approval.
- `Recovery`: always shows `sudo pmset -a disablesleep 0`.

## App Icon

The app uses Flaticon's `Shield` icon in `Assets.xcassets` for this local personal-use build:

https://www.flaticon.com/free-icon/shield_8256126

Attribution: Shield icon created by rukanicon - Flaticon. Flaticon's free license requires attribution; do not treat this asset as a public trademark or redistribute it without checking the applicable license terms.

## Detection Strategy

I did not find a documented public Codex IPC/status endpoint in the currently available local app files or official help search results. The app therefore uses the most direct local signal visible today: Codex session JSONL events.

This avoids the main false positive in the brief: "Codex is open" is not the same as "Codex is working." A running Codex app marks `Codex Detected: Yes`, but sleep protection is enabled only when recent session events indicate reasoning, tool calls, tool output, or in-progress agent messages. A final assistant response is treated as an idle boundary.

Long-running Codex-managed commands are handled by a secondary detector, with explicit ignores for persistent services such as `npm run dev`, Vite, Docker, and database servers.

## Build

Install XcodeGen:

```sh
brew install xcodegen
```

```sh
xcodegen generate
xcodebuild -project CodexSleepGuard.xcodeproj -scheme CodexSleepGuard -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

To produce a local release zip:

```sh
./scripts/package-release.sh
```

The package will be written to `dist/Codex-Sleep-Guard-macOS.zip`.

## Test

```sh
xcodebuild -project CodexSleepGuard.xcodeproj -scheme CodexSleepGuard -destination 'platform=macOS' test -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```

The current XCTest suite covers the testable core framework at 93.82% line coverage.

Carry Mode is packaged and compile-tested with the app, but the automated test suite does not toggle `pmset` or approve the privileged helper. Test Carry Mode manually before relying on lid-closed operation.

## Manual QA Checklist

- Launch the app and confirm a `Codex Sleep Guard` control window appears.
- Confirm the app has a Dock icon so the control window can be reopened if the menu bar item is hidden.
- Confirm the menu bar item appears near the right side of the menu bar as a small power/shield icon, then opens and shows `Codex Sleep Guard`.
- Toggle `Prevent sleep while Codex works` off and confirm `Status: Off` and `Sleep Protection: Disabled`, even during an active Codex task.
- Toggle `Prevent sleep while Codex works` on and confirm protection resumes when Codex is active.
- With Codex closed, confirm `Codex Detected: No` and `Sleep Protection: Disabled`.
- Open Codex but leave it idle; confirm `Codex Detected: Yes`, `Codex Activity: Idle`, and `Sleep Protection: Disabled`.
- Start a Codex task that uses tools; confirm protection becomes enabled.
- Let the task finish; confirm activity becomes idle and the five-minute grace countdown begins.
- Start another Codex task during the countdown; confirm the countdown cancels and protection remains enabled.
- Let the countdown finish; confirm protection is released.
- Leave `npm run dev`, Vite, Docker, or a database running after Codex is idle; confirm protection is disabled.
- Open Diagnostics and confirm `pmset -g assertions` output is visible.
- Keep the lid open during active Codex work if the Mac depends on Wi-Fi or a phone hotspot. A closed lid can suspend networking even while idle-sleep prevention is active.
- If using clamshell mode, test with external power, display, keyboard or mouse, and confirm the hotspot or Wi-Fi connection remains up before relying on it.
- Turn on Carry Mode and confirm macOS asks for password or Touch ID.
- If macOS reports helper approval is needed, click `Open Approval Settings`, approve the helper, then retry Carry Mode.
- Confirm the Carry Mode panel and menu bar icon turn red while Carry Mode is enabled.
- Run `pmset -g live` and confirm `SleepDisabled 1` while Carry Mode is enabled.
- Turn Carry Mode off, run `pmset -g live`, and confirm `SleepDisabled 0`.
- With `Auto off when Codex finishes` enabled, start a Codex task, enable Carry Mode, let the task finish, and confirm Carry Mode turns itself off.
- If Carry Mode does not turn off cleanly, run `sudo pmset -a disablesleep 0`.
- After wake, confirm the menu state refreshes and protection is not stuck on.
- Test on external monitor power with the lid closed if that is part of the workflow.
- Toggle Launch at Login, reboot or log out/in, and confirm the app starts from the menu bar.

## Notes

The app intentionally does not use `caffeinate`. It relies on Apple's IOKit power assertion API documented at:

https://developer.apple.com/documentation/iokit/1557134-iopmassertioncreatewithname
