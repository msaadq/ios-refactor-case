# Hot or Cold — conventions

Read this before changing code. It is the single source; `CLAUDE.md` points here, and the
per-topic detail lives in `.claude/rules/`.

## Layout

```
Hot or Cold/
  1 App/             composition root — Hot_or_ColdApp, ContentView
  1.1 Presentation/  views and view models, one folder per screen
  1.2 Domain/        value types; depends on nothing
  1.3 Data/          repositories, data sources, weather client, DTOs
  2 Utils/
  Resources/         cities.json
Hot or ColdTests/    Swift Testing suites, plus __Snapshots__ baselines
```

The numeric prefixes are inherited from the original project. Keep them; they sort the
folders into dependency order in the navigator.

The target uses `PBXFileSystemSynchronizedRootGroup`, so a new file costs **zero**
`project.pbxproj` churn. Adding one is cheap; moving or renaming one is not.

## Dependency rule

**Presentation → Data → Domain.** Domain depends on nothing. Nothing depends on Presentation.

A single target cannot enforce this — there is no module boundary to stop you. It is a review
rule. That is a deliberate trade: module boundaries earn their keep at forty modules, not at
seven files.

## The short version of everything else

- **Swift 6 language mode is on.** Do not reach for `nonisolated(unsafe)` or `@unchecked
  Sendable` to silence a diagnostic — see `.claude/rules/swift-concurrency.md` for what to do
  instead, and for the one place `@unchecked` is justified.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.** Domain and data types must say `nonisolated`
  explicitly, or their `Hashable` conformance is unusable from an actor.
- **`nonisolated async` is not off-main here.** This project enables
  `NONISOLATED_NONSENDING_BY_DEFAULT`, so such a function runs on the *caller's* executor.
  Long work needs `@concurrent`.
- **One owner per slice of state.** The repository owns it; view models derive from it and
  never keep a second copy. This is what made the original search destructive.
- **Views send `Action`s.** User intent goes through `handle(_:)`. Only SwiftUI's own async
  hooks (`.task`) call `async` methods directly.
- **Comments are 1–2 lines and say *why*.** See `.claude/rules/code-comments.md`.
- **Tests assert behaviour, not implementation.** See `.claude/rules/testing.md`.

## Running and testing

Pinned to **iPhone 17 / iOS 27.0**. Snapshot baselines are device- and OS-specific, so an
unpinned run produces diff noise across the whole suite.

```sh
xcodebuild test -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The test target is deliberately **not parallelized** — see `.claude/rules/testing.md`.

Launch with `-StressCityCount 200000` to exercise the 200k catalogue.

## Background

The reasoning behind the current shape of this code lives in the git history. The commit
messages are long on purpose — read the one that introduced a thing before overturning it, as
most of these decisions have a measurement behind them rather than a preference.
