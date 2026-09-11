# AGENTS.md — MacBook Duo repository contract

This file is the operating contract for AI coding assistants and maintainers working in this repository.

## What this is

MacBook Duo is an experimental macOS 15+ Apple Silicon app by 江灵夏草（JLXC）. It renders a desktop screenshot or local ScreenCaptureKit frames with a Metal-based hinge/perspective effect.

## Read first

1. Read `README.md` and `README.zh-CN.md` for the user-visible contract.
2. Read `PERMISSIONS.md`, `docs/license-status.md`, and `docs/release-checklist.md` before touching permissions, distribution, or publication files.
3. Run `git status --short --branch` before changing anything. Preserve unrelated work.

## Repository layout

- `Sources/` — SwiftUI/AppKit UI, Metal renderer, desktop capture, and hinge sensor code.
- `Tests/` — the standalone permission-preparation test.
- `Assets/` — app icon and design notes.
- `build.sh` — builds an arm64 app targeting macOS 15.0 and applies an ad-hoc signature.
- `test.sh` — compiles and runs the permission test without launching the app.
- `.github/` — CI, CodeQL, Dependabot, CODEOWNERS, and issue/PR forms.
- `docs/` — repository, license, and release-maintainer guidance.

## Required checks

After source or build changes, run:

```sh
./test.sh
./build.sh
codesign --verify --deep --strict "MacBook Duo.app"
git diff --check
```

Also verify that the executable is `arm64`, `Info.plist` says `LSMinimumSystemVersion` `15.0`, and the downloadable ZIP passes `unzip -t` when the package changes.

## Working rules

- Use Conventional Commit prefixes: `feat:`, `fix:`, `docs:`, `test:`, and `chore:`.
- Keep `README.md` in English and update `README.zh-CN.md` for user-visible changes.
- Keep the author attribution as 江灵夏草（JLXC） unless the author explicitly changes it.
- Do not add a license badge that implies an open-source license. The current status is documented in `docs/license-status.md`.
- Do not commit credentials, tokens, screen captures, private paths, logs, user data, or generated app bundles.
- Do not weaken macOS permission checks or use them to bypass authorization. Screen Recording must remain user-granted.
- Do not add network upload or telemetry without an explicit product decision and privacy documentation.
- Do not use `git add .` when an existing worktree may contain unrelated files; stage the reviewed candidate list explicitly.

## Remote and release boundary

A push proves only that GitHub received the commit. Before publishing a new app package, review the exact staged file list, run the checks above, and after pushing read back the remote commit, repository status, package path, and README download link. Do not claim notarization, App Store readiness, or broad hardware compatibility from a successful local build.

## Completion report

Finish with:

1. what changed;
2. the exact checks that passed;
3. what was not run or remains unverified;
4. the commit and remote URL when a push was requested.
