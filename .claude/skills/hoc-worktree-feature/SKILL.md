---
name: hoc-worktree-feature
description: Create a git worktree for a piece of Hot or Cold work at <container>/feature/<slug> on a matching feature/<slug> branch. Use when starting a new change in a fresh worktree — "make a worktree for the offline cache", "new worktree", "spin up a branch for this".
---

# New feature worktree

Adapted from the global `worktree-feature` skill, which keys off Jira ticket keys. There is no
tracker here, so the branch name comes from a short description instead. Prefixed `hoc-` so it
does not shadow the global one.

## Slug

Lowercase, hyphenated, three or four words, describing the change and not the mechanism:
`offline-cache`, not `add-swiftdata`.

## Create it

Worktrees are siblings under the container directory, one level above the repository root.

```sh
CONTAINER=$(cd "$(git rev-parse --show-toplevel)/.." && pwd)
SLUG="offline-cache"

git -C "$(git rev-parse --show-toplevel)" fetch origin
git worktree add -b "feature/$SLUG" "$CONTAINER/feature/$SLUG" origin/main
```

Branch from `origin/main` unless the work builds on another branch — this repository already
uses a stack (`feature/codebase-todos` → `feature/codebase-improvements`), so check whether the
new work belongs on top of one of those instead:

```sh
git worktree list
```

## After creating

1. `cd` into the new worktree and work only there. Never `cd` back to another worktree mid-task.
2. The stash stack is **shared across worktrees**. Do not use bare `git stash` / `git stash
   pop`; prefer a temporary WIP commit, or `git stash push -u -m "<unique-tag>"` and restore by
   SHA.
3. `.claude/`, `AGENTS.md` and `CLAUDE.md` are tracked, so the new worktree gets the conventions
   automatically.
4. Resolve packages before the first build — the worktree has its own DerivedData:

```sh
xcodebuild -resolvePackageDependencies -project "Hot or Cold.xcodeproj" -scheme "Hot or Cold"
```

## Cleaning up

```sh
git worktree remove "$CONTAINER/feature/$SLUG"
git branch -d "feature/$SLUG"
```

`git worktree remove` refuses if the tree is dirty. That is the intended behaviour — look at
what is uncommitted before forcing it.
