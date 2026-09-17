---
name: hoc-write-unit-test
description: Write a Swift Testing unit test for Hot or Cold following the project's suite layout, doubles and naming. Use when adding or changing test coverage for a repository, view model, or domain type.
---

# Write a unit test

Read `.claude/rules/testing.md` first. This is the mechanical part.

## Where it goes

| Testing | File |
|---|---|
| `CityRepository`, favorites, search folding, the 200k scan | `CityRepositoryTests.swift` |
| `CityListViewModelImpl` — debounce, paging, states | `CityListViewModelTests.swift` |
| `TemperatureRepository` — dedup, freshness, prefetch | `TemperatureRepositoryTests.swift` |
| `WeatherReading`, the DTO mapper, locale formatting | `WeatherReadingTests.swift` |
| Coordinator, routing, cross-screen state | `CityNavigationTests.swift` |

A new suite only for a genuinely new unit.

## Shape

```swift
@MainActor
@Suite("City repository")
struct CityRepositoryTests {
    private func makeRepository(
        cities: [City] = StubCityDataSource.sample,
        store: FavoritesStore = InMemoryFavoritesStore()
    ) -> CityRepository {
        CityRepository(dataSource: StubCityDataSource(cities), store: store)
    }

    /// One or two lines on the non-obvious reason this behaviour matters. Skip if the name
    /// already says it.
    @Test("Favorites surface newest first, not in catalogue order")
    func favoritesAreOrderedNewestFirst() async throws { ... }
}
```

- `@MainActor` on the suite when it touches `CityRepository` or a view model; omit for the
  actor-based `TemperatureRepository`.
- `@Test("…")` display name is a **sentence stating the claim**, and the function name is the
  same claim in camelCase.
- `#require` for things that must exist, `#expect` for the assertion itself.

## Doubles

Use the app target's `#if DEBUG` doubles — do not write new ones inline unless the behaviour
you need is genuinely absent:

- `StubCityDataSource(_ cities:)` / `.sample` — four cities including `Tromsø`, for folding
- `StubWeatherClient(result:delay:)` with `.callCount` for deduplication assertions
- `InMemoryFavoritesStore(initial:failOnSave:)` — `failOnSave` drives the rollback path
- `WeatherReading.fixture(celsius:observedAt:validFor:)` — `observedAt: .distantPast` for stale

## Driving async work

View-model actions spawn internal tasks. Send the action, then sleep past the interval:

```swift
viewModel.handle(.didChangeQuery("tok"))
try await Task.sleep(for: .milliseconds(500))   // debounce is 300 ms
```

## Prove the test is load-bearing

Before you are finished, **break the production code and watch the test fail.** A test that
passes against the bug it claims to guard is worse than no test. Then put the code back.

Finally run the whole suite, not just yours:

```sh
xcodebuild test -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
