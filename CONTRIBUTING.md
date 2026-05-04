# Contributing to meta_wearables_dat_flutter

Thanks for your interest in improving this plugin. This document covers the
basics; please also read [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Before you start

This is an **unofficial** plugin. It is not affiliated with Meta. Issues with
Meta's underlying SDKs (`meta-wearables-dat-ios`, `meta-wearables-dat-android`)
should be filed against those upstream repositories, not here. Issues against
this plugin should be reproducible with our `samples/camera_access/` app or
explained with enough Dart/Swift/Kotlin context that a maintainer can repro.

## Workflow

1. Fork [`iSee-Labs/meta-wearables-dat-flutter`](https://github.com/iSee-Labs/meta-wearables-dat-flutter)
   and create a topic branch off `main`:

   ```bash
   git checkout -b feat/your-feature
   ```

2. Make your change. Keep changes vertical: every PR should leave the plugin
   in a buildable, runnable state on both iOS and Android. The repository
   evolves in commit-sized vertical slices (see `CURSOR.md`).

3. Run the gating checks locally **before pushing**:

   ```bash
   flutter pub get
   flutter analyze              # must report "No issues found"
   flutter test
   cd example && flutter run    # iOS and Android
   ```

4. Open a pull request against `main` and fill out the description with:
   - what changed and why,
   - platforms tested (iOS version, Android API level, device or mock),
   - any new permissions / `Info.plist` / `AndroidManifest.xml` entries,
   - screenshots or short screen recordings for UI-affecting changes.

## Coding conventions

- Dart code follows
  [`very_good_analysis`](https://pub.dev/packages/very_good_analysis). All
  public APIs require dartdoc.
- Swift code follows the style of Meta's
  [`meta-wearables-dat-ios` Camera Access sample](https://github.com/facebook/meta-wearables-dat-ios/tree/main/samples/CameraAccess).
- Kotlin code follows the style of Meta's
  [`meta-wearables-dat-android` Camera Access sample](https://github.com/facebook/meta-wearables-dat-android/tree/main/samples/CameraAccess).
- Public Dart APIs return `Future<T>` or `Stream<T>`. No callbacks.
- Video frames **must** flow through Flutter's texture registry. Never
  serialize frames over a `MethodChannel`.

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/). Examples:

- `feat: add capturePhoto with HEIC support`
- `fix(android): release surface before stopping stream`
- `docs: clarify GitHub Packages auth`
- `chore: bump mwdat to 0.6.1`

## Reproducing issues

Please reproduce bugs against the
[`samples/camera_access/`](samples/camera_access/) app whenever possible — it
mirrors Meta's own Camera Access sample on both platforms and is the lowest-
friction way to isolate plugin bugs from app-level wiring.

## Licensing

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
