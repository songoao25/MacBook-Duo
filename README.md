# MacBook Duo

[![CI](https://github.com/songoao25/MacBook-Duo/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/songoao25/MacBook-Duo/actions/workflows/ci.yml)
[![CodeQL](https://github.com/songoao25/MacBook-Duo/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/songoao25/MacBook-Duo/actions/workflows/codeql.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-blue)](https://www.apple.com/macos/)
[![Architecture](https://img.shields.io/badge/architecture-Apple%20Silicon%20%28arm64%29-6f42c1)](https://support.apple.com/en-us/116943)
[![Status](https://img.shields.io/badge/status-beta%200.6-orange)](CHANGELOG.md)
[![License: not specified](https://img.shields.io/badge/license-not%20specified-lightgrey)](docs/license-status.md)

> Author: 江灵夏草（JLXC）

MacBook Duo is an experimental macOS desktop visual app. It uses a MacBook hinge angle to animate perspective, floating-glass, and frosted-glass effects over a desktop screenshot or a live desktop capture.

This repository contains the source snapshot, build scripts, tests, icons, and the distributable development build. It is not a production-signed or notarized application.

## Download

[Download MacBook Duo.app.zip](https://raw.githubusercontent.com/songoao25/MacBook-Duo/main/MacBook%20Duo.app.zip)

The archive contains `MacBook Duo.app`. Unzip it before opening. The current package is an Apple Silicon (`arm64`) beta build 0.6. Gatekeeper may reject this ad-hoc development signature; use the source build if you need a locally signed development app.

## Features

- Screenshot preview with manual hinge-angle simulation.
- Live desktop mode using ScreenCaptureKit and Metal.
- Hinge sensor input when the MacBook model exposes a compatible HID path.
- Saved open-angle calibration and keyboard shortcuts.
- Local image processing; the app does not upload desktop frames or write a video recording.
- Global overlay mode that can be enabled or stopped from the menu bar.

## Requirements

- macOS 15.0 or later.
- Apple Silicon Mac (`arm64`).
- A Mac with Metal support.
- Live mode is intended for the built-in MacBook display and is not guaranteed on every model.

Screenshot-based manual simulation remains available when a hinge sensor is unavailable.

## Install and use

1. Download the ZIP above and unzip it.
2. Open `MacBook Duo.app`.
3. In screenshot mode, import a full desktop screenshot and select **Start Test**.
4. Adjust the simulated angle, depth, and frosted-glass strength. Press `⌘K` to save the preferred endpoint.
5. For live mode, grant Screen Recording permission when macOS asks. Frames are processed locally.

The distributed app is a development build with an ad-hoc signature. Review the source and build it locally when Gatekeeper or your security policy does not accept the downloaded package.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘H` | Hide or restore screenshot-mode controls |
| `Esc` | Show screenshot-mode controls |
| `⌘K` | Save the current angle as the open endpoint |
| `⌘B` | Toggle original-image comparison |
| `⌘Q` | Quit |
| `⌘⇧G` | Toggle live desktop effect |
| `⌘⇧K` | Save the live hinge endpoint |
| `⌘⇧Esc` | Stop live mode and return to settings |

## Build from source

Install Apple Command Line Tools, then run:

```sh
./test.sh
./build.sh
open "MacBook Duo.app"
```

There is intentionally no Xcode project or third-party dependency. `build.sh` invokes the system Swift compiler, targets `arm64-apple-macosx15.0`, copies the app resources, and applies an ad-hoc local signature. `test.sh` compiles and runs the permission-migration test without launching the app or changing Screen Recording permission.

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/` | SwiftUI/AppKit UI, Metal rendering, live capture, and hinge sensor code |
| `Tests/` | Permission-preparation executable test |
| `Assets/` | App icon and design notes |
| `Info.plist` | Bundle metadata and privacy usage description |
| `build.sh` | Reproducible local app build entry point |
| `test.sh` | Lightweight source test entry point |
| `GLOBAL-README.md` | Live global-overlay mode notes |
| `PERMISSIONS.md` | Screen Recording permission migration notes |
| `docs/` | License, repository, and release-maintainer guidance |

## Privacy and permissions

Live mode requires the user to grant Screen Recording access. The current implementation uses ScreenCaptureKit and Metal locally; source comments and documentation state that frames are not sent over the network and are not saved as a video. Calibration values are stored in the app's local `UserDefaults` domain.

The permission-preparation helper resets only this app's own Screen Recording entry once per code identity. It is a development-build migration aid, not an authorization bypass. See [PERMISSIONS.md](PERMISSIONS.md).

## Known limitations

- Hinge HID support varies by MacBook model.
- Live mode is designed for the built-in display and has not been validated against every full-screen app, Space, protected video surface, or external monitor.
- The downloaded app is ad hoc signed and not notarized.
- The project has no open-source license at this time; see [the license status](docs/license-status.md).

## References and attribution

The renderer is an independent implementation. Development references are listed in the source documentation and include [Duo-animation](https://github.com/Atomicx7/Duo-animation) and [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor). Their licenses and notices remain the responsibility of anyone making a derivative work.

## Repository guidance

- [中文 README](README.zh-CN.md)
- [Contributing guide](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Support guide](SUPPORT.md)
- [Agent instructions](AGENTS.md)
- [Release checklist](docs/release-checklist.md)

## License and author

Copyright © 2026 江灵夏草（JLXC）. This repository does not currently grant a new open-source license. Do not redistribute, relicense, or reuse the source as an open-source project without the author's separate permission.
