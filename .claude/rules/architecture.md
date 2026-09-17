# Architecture

## The dependency rule

**Presentation → Data → Domain.** Domain depends on nothing. Nothing depends on Presentation.

There is no build-system enforcement — one target, no module boundaries. This is a review rule.
The trade is deliberate: module boundaries earn their keep at forty modules, not seven files.

## Where new code goes

| It is… | Put it in |
|---|---|
| A value type with no behaviour of its own | `1.2 Domain/` |
| Something that fetches, caches or persists | `1.3 Data/` |
| A screen, or state derived for a screen | `1.1 Presentation/<Feature>/` |
| Presentation formatting of a domain type | `1.1 Presentation/<Feature>/Type+Concern.swift` |

Prefer a new file over growing an existing one past coherence. The target uses
`PBXFileSystemSynchronizedRootGroup`, so a new file costs zero `project.pbxproj` churn.

Prefer editing in place over moving code between files. Git renders a move as a deletion plus an
addition, which hides the actual change.

## One owner per slice of state

The repository owns state; view models derive from it and never keep a second copy.

The original bug this prevents: `cities` was both the source list and the filter output, so each
keystroke filtered the already-filtered result and deleting a character restored nothing.
Filtering is now a derived read that never writes back.

## Unidirectional flow

- The view reads `viewState` and sends `Action`s through `handle(_:)`.
- `handle(_:)` is **synchronous**. Where it needs async work it owns a `Task` it can cancel.
- Only SwiftUI's own async hooks — `.task` — call `async` methods directly. Those contexts own
  their cancellation, and the view model should not re-spawn work it cannot tie to the view's
  lifetime.

## Navigation is data

Routes live on the view model, not inside a rendering closure, so a push is state a test can
read.

```swift
enum CityRoute: Hashable { case detail(CityID) }
```

**A route carries an ID, never a model.** A pushed `City` is a snapshot that goes stale the
moment another screen edits it — and `City`'s `Hashable` includes `searchKey`, so changing how
search folds would silently change navigation identity.

**If a route case ever gains a display-only associated value, write `==` and `hash` by hand.**
`NavigationPath` uses `Hashable` for destination *identity*; cosmetic payload participating in
equality turns one destination into several. The synthesised conformance is correct only while
every associated value is identifying.

## Protocols earn their place

Every protocol boundary here exists because a test or a second implementation needs it — not
because a diagram looked tidier. Before adding one, name the caller that needs the seam.

## Screens do not reach past what they need

`CityDetailViewModel` depends on `FavoriteToggling`, not on `CityRepository`. It flips a star;
it has no business holding the catalogue.

Note the consequence: state shared through a narrow protocol still has to *propagate*. The
repository is `@Observable`, so rows repaint on their own — but anything derived into
`viewState` (such as section membership) must be recomputed explicitly. See
`CityListViewModelImpl.load()`.
