# Draft bug report for `facebook/meta-wearables-dat-ios`

Status: not yet filed. File at
<https://github.com/facebook/meta-wearables-dat-ios/issues/new> and replace
this file's status line with the issue link.

---

**Title:** MWDATCore 1.0.0 aborts on iOS 17.2–18.x when any code calls
`objc_copyClassList` (XCTest, analytics SDKs)

**SDK version:** 1.0.0 (`facebook/meta-wearables-dat-ios`, revision
`1f38beecba83c4c8b5e343540f9cd615323ab19a`)

**Xcode / host:** Xcode 27.0 (27A266a), macOS 27.0.1

**Affected runtimes:** iOS 18.0 (22A3351) and iOS 18.5 (22F77) simulators.
Not reproducible on iOS 26.5 (23F77) or iOS 27.0 (24A434).

## Summary

`MWDATCore` weakly links Swift types that exist only on iOS 26, for example
`Network.NetworkConnection`, `Network.NetworkBrowser`, `WiFiAware.WAEndpoint`
and `WiFiAware.WAPairedDevice` (`dyld_info -imports` lists them as
`[weak-import]`). Regular SDK code paths check availability before using
them, so the SDK works on iOS 18. However, any call to `objc_copyClassList`
(or `objc_getClassList`) realizes every class in the process. On iOS below 26
this forces the metadata of those classes to initialize, the Swift runtime
cannot resolve the symbolic reference, and the process aborts.

XCTest calls `objc_copyClassList` at launch to discover test cases, so **every
XCTest bundle hosted by an app that links MWDATCore crashes on iOS 17.2–18.x
simulators before a single test runs.** Analytics, crash-reporting and
dependency-injection SDKs that enumerate classes trigger the same abort in
production apps.

## Steps to reproduce

1. Create an iOS app that links `MWDATCore` 1.0.0 via SwiftPM
   (deployment target 17.2).
2. In `application(_:didFinishLaunchingWithOptions:)` add:

   ```swift
   var count: UInt32 = 0
   if let list = objc_copyClassList(&count) {
     free(UnsafeMutableRawPointer(list))
   }
   ```

3. Run on an iOS 18.5 simulator.

Alternatively, add an empty XCTest unit-test target to the app and run it on
an iOS 18.x simulator; the test host crashes during
`+[XCTestCase(RuntimeUtilities) _allSubclasses]`.

## Expected

Class enumeration completes; iOS 26-only types stay unrealized or fail
gracefully on older runtimes.

## Actual

```
Runner: (libswiftCore.dylib) Failed to look up symbolic reference at 0x1032ef694
  - offset 860876 - symbol <unknown> in .../Runner.app/Frameworks/MWDATCore.framework/MWDATCore
```

followed by `SIGABRT`. Crashing thread:

```
libswiftCore.dylib  swift::fatalError
libswiftCore.dylib  swift::ResolveAsSymbolicReference::operator()
libswiftCore.dylib  swift::Demangle::__runtime::Demangler::demangleSymbolicReference
libswiftCore.dylib  swift_getTypeByMangledName
libswiftCore.dylib  swift_getTypeByMangledNameInContextInMetadataStateImpl
MWDATCore           <stripped>
MWDATCore           <stripped>
MWDATCore           <stripped>
libswiftCore.dylib  swift::MetadataCacheEntryBase<SingletonMetadataCacheEntry>::doInitialization
libswiftCore.dylib  swift_getSingletonMetadata
MWDATCore           <stripped>
libobjc.A.dylib     realizeClassMaybeSwiftMaybeRelock
libobjc.A.dylib     realizeAllClasses
libobjc.A.dylib     objc_copyClassList
Runner              AppDelegate.application(_:didFinishLaunchingWithOptions:)
```

## Impact

- No native XCTest coverage is possible on iOS 17/18 simulators for any app
  that links MWDATCore.
- Apps that ship a class-enumerating SDK crash at launch for iOS 18 users.

## Suggested fix

Avoid `@objc`-visible classes whose Swift metadata references iOS 26-only
types without availability-guarded storage, or mark those types with
`@available(iOS 26, *)` so the runtime does not try to realize them on older
systems.

## Workarounds we use

- Run XCTest bundles only on iOS 26+ simulators.
- Audit app dependencies for `objc_copyClassList` / `objc_getClassList`
  before shipping to iOS 18 users.
