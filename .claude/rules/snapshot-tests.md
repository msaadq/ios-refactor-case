# Snapshot tests

`pointfreeco/swift-snapshot-testing`, in `CitySnapshotTests.swift`, baselines in
`Hot or ColdTests/__Snapshots__/`.

## Pin the device and the OS

Baselines are recorded on **iPhone 17 / iOS 27.0**. They encode that device's scale, safe-area
insets and system font metrics, so a run on anything else fails every baseline at once — noise
that buries a real regression.

```sh
-destination 'platform=iOS Simulator,name=iPhone 17'
```

## Never commit a record mode

Recording is driven by an environment variable:

```swift
@Suite(.snapshots(record: ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == nil ? .missing : .all))
```

A committed `record: .all` makes every snapshot test pass unconditionally, silently, forever. It
is the single worst failure mode of this technique — the suite stays green while the UI rots.

`.missing` is the default: a baseline that is absent gets written **and the test fails**, so a
forgotten commit surfaces immediately rather than passing on someone else's machine.

To re-record after an intended UI change:

```sh
SNAPSHOT_RECORD=1 xcodebuild test -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Hot or ColdTests/CitySnapshotTests"
```

Then **look at the diff before committing it**. A re-recorded baseline is an assertion that the
new rendering is correct; if you did not open the PNG, you did not assert anything.

## What to snapshot

One baseline per *state*, not per component. The states are the `ViewState` cases — loading,
loaded with and without favorites, empty, error — plus any screen whose layout can break.

**Include a Bokmål baseline.** It is the one that catches what unit tests cannot: a lost
translation, a comma decimal separator reverting to a point, or a longer string breaking the
layout.

## Feed the view a stub, not the real view model

Driving `CityListViewModelImpl` into `.error` needs a failing data source, and into `.loading`
a request that never returns. A stub with a settable `viewState`, behind the existing protocol,
gives every state directly and deterministically.

Nothing in a snapshot may vary between runs: no `Date()` in rendered text, no random data, no
network.
