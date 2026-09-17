---
name: hoc-run-app
description: Build Hot or Cold and run it on the pinned iPhone 17 simulator, optionally with the 200k stress catalogue or a forced locale. Use when asked to run, launch, or screenshot the app, or to confirm a change works in the real app rather than only in tests.
---

# Run Hot or Cold

The simulator is pinned to **iPhone 17 / iOS 27.0**. Do not substitute another device — the
snapshot baselines and every performance figure quoted in the git history are tied to it.

## Build, install, launch

```sh
DEVICE=$(xcrun simctl list devices available | grep -m1 "iPhone 17 (" | grep -oE "[0-9A-F-]{36}")
xcrun simctl boot "$DEVICE" 2>/dev/null

xcodebuild build -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination "platform=iOS Simulator,id=$DEVICE" | grep -E "error:|warning:|BUILD"

APP=$(xcodebuild -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination "platform=iOS Simulator,id=$DEVICE" -showBuildSettings \
  | grep -m1 BUILT_PRODUCTS_DIR | sed 's/.*= //')/"Hot or Cold.app"

xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.propely.Hot-or-Cold
```

The bundle identifier is `com.propely.Hot-or-Cold`.

## Useful launch variations

```sh
# 200,000 generated cities — exercises paging, the off-main scan, and the lazy prefetch path
xcrun simctl launch "$DEVICE" com.propely.Hot-or-Cold -StressCityCount 200000

# Force a locale; nb_NO is the one worth checking, it changes words and numbers
xcrun simctl launch "$DEVICE" com.propely.Hot-or-Cold -AppleLanguages "(nb)" -AppleLocale nb_NO
```

## Screenshot

```sh
xcrun simctl io "$DEVICE" screenshot /tmp/hoc.png
```

Then read the PNG. For tapping through a flow, use the Xcode device-interaction tools and take
coordinates from the **hierarchy dump**, never guessed from the image.

## Before concluding anything from a run

Favorites persist in `UserDefaults`, so a simulator carries state between runs and a previous
session's favorites will look like a partition bug. Reinstall first when the state matters:

```sh
xcrun simctl uninstall "$DEVICE" com.propely.Hot-or-Cold
```
