---
name: hoc-worktree-review
description: Check out a Hot or Cold pull request into a review worktree at <container>/review/pr-<number>-<slug>, build it, and run the suite. Use when a PR needs to be pulled down locally to review, build, or test — "review PR 3", "check this PR out so I can run it".
---

# PR review worktree

Adapted from the global `worktree-review` skill for this repository's remotes, and prefixed
`hoc-` so it does not shadow it. Note there are two remotes: `origin` is the fork that carries
the branches, `upstream` is the original repository.

```sh
git remote -v
```

## Check it out

```sh
CONTAINER=$(cd "$(git rev-parse --show-toplevel)/.." && pwd)
PR=3

gh pr view "$PR" --json headRefName,title,baseRefName
SLUG=$(gh pr view "$PR" --json headRefName -q .headRefName | tr '/' '-')

git fetch origin "pull/$PR/head:pr-$PR"
git worktree add "$CONTAINER/review/pr-$PR-$SLUG" "pr-$PR"
```

If `gh` targets the wrong repository, pass `--repo` explicitly — the fork and the upstream both
exist and `gh` will not always guess right.

## Review it, do not just read it

```sh
cd "$CONTAINER/review/pr-$PR-$SLUG"
xcodebuild -resolvePackageDependencies -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold"
xcodebuild test -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold" \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Then walk `.claude/skills/hoc-pre-commit-review/SKILL.md` over the diff:

```sh
git diff "$(gh pr view "$PR" --json baseRefName -q .baseRefName)"...HEAD
```

Two checks that matter most here and are easy to miss by reading alone:

- **Snapshot baselines.** If any PNG changed, open it. A re-recorded baseline is an assertion,
  and an unreviewed one asserts nothing.
- **`@concurrent`.** Its absence on a new long-running `nonisolated async` function compiles,
  passes, and silently moves the work to the main thread.

If the change is visual, run the app (`hoc-run-app`) rather than trusting the diff.

## Clean up

```sh
git worktree remove "$CONTAINER/review/pr-$PR-$SLUG"
git branch -D "pr-$PR"
```
