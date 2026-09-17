# Swift concurrency

Swift 6 language mode is on for both targets. The compiler is the regression test for
everything below — do not silence it.

## Two project settings that change what code means

**`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.** Every unannotated declaration is main-actor
isolated. Domain and data types must therefore say `nonisolated` explicitly:

```swift
nonisolated struct CityID: Hashable, Sendable, Codable { ... }
```

Without it, `CityID`'s `Hashable` conformance is main-actor isolated and `TemperatureRepository`
(an actor) cannot key a dictionary with it. That is a hard error, and the fix is not to move the
repository to the main actor.

**`SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT = YES`.** A `nonisolated async`
function runs on the **caller's** executor. `async` alone buys you nothing.

```swift
@concurrent
nonisolated static func sections(in cities: [City], ...) async throws -> Sections
```

Drop `@concurrent` there and a 200,000-item scan runs on the main thread while still compiling
and still returning the right answer. This was measured, not theorised: 768 ms of catalogue
generation on `Main Thread` before the annotation was added.

**Any long-running `nonisolated async` function needs `@concurrent`.** Treat its absence on
one as a bug.

## Choosing an isolation

The access pattern picks the mechanism. Consistency for its own sake is not a reason.

| State | Mechanism | Why |
|---|---|---|
| Cities, favorites | `@MainActor` | Read *synchronously* while SwiftUI lays out rows — you cannot `await` in `body` |
| Temperature cache | `actor` | Read from `.task`, which can `await`, and written from off-main URLSession callbacks |

## Actor re-entrancy

Actors suspend at every `await`, and another task may enter. A `Bool` "already fetching" flag
does not deduplicate:

```swift
if let hit = cached[id] { return hit }
let value = try await client.fetch(city)   // ⚠️ actor released here
cached[id] = value                         // all 15 callers got past the check
```

Store the `Task`, not a flag. It is created and registered *synchronously*, before the first
suspension, so caller #2 finds it and joins:

```swift
let task = Task { [client] in try await client.currentWeather(at: city.coordinate) }
inFlight[city.id] = task
```

## Forbidden

- **`nonisolated(unsafe)`** — it asserts a guarantee the compiler cannot check, and in the
  original code it was hiding a real data race on a `@State` dictionary.
- **`@unchecked Sendable` to silence a diagnostic.** The two uses in this codebase are
  justified and commented: `UserDefaults` is documented thread-safe but unmarked, and
  `StubWeatherClient` guards a call counter with an `NSLock`. Anything else needs the same
  standard of proof.
- **`DispatchQueue` hops to fake asynchrony.** If there is nothing to await, the function is
  not async.
