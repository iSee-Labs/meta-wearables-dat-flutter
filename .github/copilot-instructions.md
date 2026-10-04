# meta_wearables_dat_flutter — Copilot Instructions

> Canonical context: [`../AGENTS.md`](../AGENTS.md) — read it first.
>
> Per-topic skills: [`../.claude/skills/`](../.claude/skills/) ·
> Cursor rule: [`../.cursor/rules/meta-wearables-dat.mdc`](../.cursor/rules/meta-wearables-dat.mdc) ·
> Meta DAT reference: <https://wearables.developer.meta.com/llms.txt?full=true>

Unofficial Flutter plugin (not affiliated with Meta) bridging Meta's iOS
and Android Wearables Device Access Toolkit. Plugin **1.0.0** on DAT
**1.0.0**.

## Top rules

1. Never invent API names. The code is the authority:
   `lib/meta_wearables_dat_flutter.dart`, `lib/src/models/**`,
   `lib/src/channels.dart`.
2. Channel names live in `lib/src/channels.dart`. Add a method or event
   channel in Dart, Swift and Kotlin together and keep
   `dart run tool/check_channel_parity.dart` green.
3. Errors are sealed `DatError` subclasses with typed `reason`,
   `category`, `recoveryAction`. State channels carry strings.
4. Texture path never sends frames over MethodChannel;
   `videoFramesStream` is opt-in and subscriber-gated;
   `stopStreamSession()` unregisters the texture.
5. Experimental APIs (Inputs, Motion, Speech, voice invocations, high-res
   photo, in-stream audio) are `@experimental` and cannot ship to
   production release channels.
6. iOS: SPM only, iOS 17.2, Xcode 26.4+. Android: Maven Central (no
   token), minSdk 31, `FlutterFragmentActivity`.
7. Android `StateFlow`s start at `STOPPED`; don't treat it as terminal.
   No `async*` with awaited teardown in public Dart streams.
8. Dart: `very_good_analysis`, `flutter analyze --fatal-infos`, dartdoc on
   every public symbol, `Future<T>`/`Stream<T>` only.
9. Gates: `flutter test --coverage` + `dart run tool/coverage_gate.dart --min 90`,
   `dart run tool/check_versions.dart`, Kotlin and Swift unit tests,
   integration tests in `example/integration_test/`.
10. When uncertain about Meta SDK behavior, stop and ask.
