---
name: hoc-write-snapshot-test
description: Add a snapshot test for a Hot or Cold screen or view state, using the project's stub view models and pinned device config. Use when a new screen or ViewState case needs visual coverage.
---

# Write a snapshot test

Read `.claude/rules/snapshot-tests.md` first — especially the part about never committing a
record mode.

## Add it to the existing suite

`Hot or ColdTests/CitySnapshotTests.swift`. The suite trait and the shared `device` config are
already set up; do not redeclare them.

```swift
@Test("Loaded with favorites — two sections")
func loadedWithFavorites() {
    assertSnapshot(
        of: AnyView(list(
            .loaded(favorites: [Self.tromso], others: [Self.oslo, Self.tokyo], totalOthers: 2),
            favorites: [Self.tromso.id]
        )),
        as: device
    )
}
```

`AnyView` is needed because `device` is a concrete `Snapshotting<AnyView, UIImage>`.

## Feed it a stub, never the real view model

`StubListViewModel` and `StubDetailViewModel` are in the same file. A settable `viewState`
reaches `.loading` and `.error` directly; driving the real view model there needs a request that
never returns and a data source that fails.

Nothing in the rendered view may vary between runs — no `Date()` in text, no random data, no
network.

## Cover the state, and cover Bokmål

A new `ViewState` case needs a baseline. A new *screen* needs both an English and an `nb_NO`
baseline, because the Norwegian one is what catches a lost translation, a decimal comma
reverting to a point, or a longer string breaking the layout.

Pass the locale through the helper — the views read `\.locale` from the environment, so both
the words and the numbers follow it:

```swift
list(..., locale: Locale(identifier: "nb_NO"))
```

## Record, then look

```sh
SNAPSHOT_RECORD=1 xcodebuild test -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Hot or ColdTests/CitySnapshotTests"
```

Record mode writes the baselines **and fails the tests** — that is expected, not an error.

Then:

1. **Open the new PNG and check it is what you meant.** An unexamined baseline asserts nothing.
2. Run the suite twice without `SNAPSHOT_RECORD` and confirm it is green both times. A baseline
   that captures an animation mid-frame will pass once and flake forever after.
