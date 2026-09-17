# Code comments

The inherited code is almost comment-free. Match that density. A wall of prose explaining a
three-line change reads as padding, and comments are part of the diff.

## The rule

- **One to two lines maximum**, including `///` doc comments.
- **Lead with the why.** If a sentence restates the declaration below it — its name, its
  parameters, its obvious behaviour — cut it.
- **Never** a multi-paragraph `///` block narrating what the code already says.
- `// MARK: -` headers are organisational, not explanatory — exempt.
- **No planning vocabulary in source.** No defect IDs, no TODO numbers, no "Section B". That
  numbering is local to the working notes it came from and is meaningless, or worse
  misleading, to anyone reading the repository. State the constraint itself.

## The keep-or-cut test

Keep it if a future reader would **break something** without it: an async race, a deliberate
non-obvious API choice, a workaround for an upstream bug.

Cut it if it narrates the code.

## Model

```swift
/// `@concurrent` forces this off the caller's actor. Without it, a `nonisolated async`
/// function runs on the caller's executor — which would put a 200k scan on the main thread.
```

Two lines, pure *why*, and someone who deleted the annotation would break something the
compiler cannot catch.

## Anti-model

The inherited `CityListViewModel.swift:57`:

```swift
// Pre-warm the temperature cache so the first scroll feels snappy.
```

…on a function that slept for two seconds and printed. A comment describing intent the code
does not implement is worse than no comment, because it is believed.

## Where the long reasoning goes

The commit message. It stays accurate as the code moves; a comment copy goes stale the moment
it does.
