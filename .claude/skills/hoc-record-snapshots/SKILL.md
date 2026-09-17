---
name: hoc-record-snapshots
description: Re-record Hot or Cold snapshot baselines after an intended UI change, on the pinned simulator, and review the resulting diff. Use when snapshot tests fail because the UI legitimately changed.
---

# Re-record snapshot baselines

Only after an **intended** UI change. A failing snapshot is a question, not a chore — answer it
before re-recording.

## First: is the failure real?

Check these before touching a baseline.

| Failure looks like | Likely cause |
|---|---|
| Every baseline fails at once | Wrong simulator. Baselines are pinned to iPhone 17 / iOS 27.0 |
| One baseline fails, diff is a few pixels | Genuine rendering change — inspect it |
| Text changed in the `nb` baseline only | A translation was lost or a key renamed |
| Flaky between runs | The view renders something non-deterministic |

The failure message names the reference and the freshly rendered image. **Open both.** If you
cannot explain the difference, do not re-record it.

## Recording

```sh
SNAPSHOT_RECORD=1 xcodebuild test -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"Hot or ColdTests/CitySnapshotTests"
```

Record mode writes baselines **and fails every test it wrote**. That is how it reports what it
did; it is not an error.

Narrow it when only one changed:

```sh
-only-testing:"Hot or ColdTests/CitySnapshotTests/loadedWithFavorites"
```

## Then

1. `git diff --stat` — only the baselines you expected should have moved. A change touching all
   seven usually means wrong device, not a redesign.
2. **Open each changed PNG.** Committing a re-recorded baseline is asserting the new rendering
   is correct.
3. Re-run **without** `SNAPSHOT_RECORD` and confirm green.
4. Never commit `record: .all` in the suite trait. It makes every snapshot test pass forever.
