# Testing

Swift Testing, not XCTest. One suite per unit, named for the thing it exercises.

## What to test

Test a **behaviour someone could break**, and say in the test name what that behaviour is.
`favoritesSurviveRelaunch` is a claim; `testCityRepository` is not.

Worth a test:

- A decision that is not obvious from the code — newest-first favorite ordering, the paging
  window, the batch/lazy prefetch split.
- An edge that a reasonable change would break — optimistic rollback, cancellation, a stale
  cache entry, an un-favorite leaving the remaining order intact.
- **Anything found by running the app rather than reading it.** Those are the ones that will
  regress, because nothing about the code looked wrong the first time.

Not worth a test: getters, `init`, enum round-trips, or anything whose test would restate the
implementation line for line.

## Test the seam, not the internals

Drive the public channel. A view-model test sends `handle(.didChangeQuery("tok"))`, not the
private `search(_:)` behind it. If a test needs `@testable` to reach past the public surface,
that is usually a sign the surface is wrong.

## Doubles

`StubCityDataSource`, `StubWeatherClient`, `InMemoryFavoritesStore` live in the app target under
`#if DEBUG`, so previews and tests share them.

**No test touches the network.** Two deliberate exceptions to pure isolation, both justified:

- A test may read the real `cities.json` from the bundle, so a malformed resource fails at test
  time instead of via `assertionFailure` at launch.
- `favoritesSurviveRelaunch` exercises the **shipping** `UserDefaults` store over a throwaway
  suite torn down in a `defer`, because the ordering bug it guards against lived in that
  implementation and testing only the double would have missed it.

## Timing

Do not assert on durations. The one test that measures concurrency
(`largeScanStaysOffTheMainActor`) uses a threshold orders of magnitude below what a free main
actor achieves, so it fails only on a genuine regression.

Tests that wait for spawned work sleep past the debounce interval rather than polling. Keep
those sleeps generous; a flaky test is worse than a slow one.

## The test target is not parallelized

`parallelizable = "NO"` in the scheme, deliberately.

`largeScanStaysOffTheMainActor` measures whether the main actor stays free while a 200k scan
runs — a **global** property. Swift Testing runs suites concurrently, and seven
`@MainActor` snapshot tests rendering at the same time starved it to a single tick, failing a
test with nothing wrong with it. Snapshot tests are main-thread-bound and do not parallelize
usefully anyway. The whole suite runs in under three seconds.

If you re-enable parallelization, that test will flake, and it will not be its fault.
