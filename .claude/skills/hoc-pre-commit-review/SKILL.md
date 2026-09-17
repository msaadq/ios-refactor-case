---
name: hoc-pre-commit-review
description: Review staged and unstaged Hot or Cold changes against this project's rules before committing — concurrency, architecture, comments, tests, and diff shape. Use as the gate before any commit here.
---

# Pre-commit review

Review the change you are about to commit against this repository's rules. Read the diff, not
your memory of writing it.

```sh
git diff            # unstaged
git diff --cached   # staged
```

## Concurrency

- [ ] Any new `nonisolated async` function doing real work is marked `@concurrent`. Without it
      the work runs on the **caller's** executor — silently, and still correct-looking.
- [ ] No new `nonisolated(unsafe)`. No new `@unchecked Sendable` without a one-line comment
      proving the guarantee.
- [ ] New domain or data types are explicitly `nonisolated`.
- [ ] Anything cached behind an `await` stores the `Task`, not a `Bool`.

## Architecture

- [ ] Dependency direction holds: Presentation → Data → Domain.
- [ ] No second copy of state that a repository already owns.
- [ ] New user intent goes through `handle(_:)`, not a new public method on the view model.
- [ ] A new protocol has a named caller or test that needs the seam.
- [ ] State shared across screens **propagates** — if something derives into `viewState`, find
      where it is recomputed.

## Diff shape

- [ ] Nothing renamed or moved that did not have to be. Git renders a move as delete + add and
      buries the real change.
- [ ] A new file only for a genuinely new concept.
- [ ] Each commit builds and passes on its own.

## Comments

- [ ] Every new comment is 1–2 lines and says *why*.
- [ ] No defect IDs, TODO numbers, or "Section B" in source.
- [ ] No comment describing behaviour the code does not implement.

## Tests

- [ ] New behaviour has a test, and the test was watched failing before it passed.
- [ ] No test asserts on timing beyond a debounce interval.
- [ ] A UI change has a snapshot baseline, and the PNG was opened.

## Then run it

```sh
xcodebuild test -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Zero build warnings is the standard, not "no new warnings".

## Report honestly

If something is left undone, say so in the summary rather than in a comment in the code. If a
test is failing, quote it. Do not describe work as verified that was not run.
