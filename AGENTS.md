# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Multi-agent: you share this checkout and `main`

Other agents work in this same checkout at the same time as you, and commit straight to `main`.
Touch only what you own: the files, changes, processes and build outputs your task created or was
asked to change. Leave anything else as you found it, even if it looks wrong, unfinished or
unrelated — it is another agent's work in progress. Report anything unexpected in your summary
instead of fixing it.

### Committing

- Stage your own files by path (`git add <path>…`, or `git add -p` when a file holds someone
  else's edits too). Run `git status` and `git diff --cached` before committing; the index should
  hold only your change.
- Commit to `main` with a Conventional Commit message — `cog.toml` drives the release from them.
- Leave the working tree of others alone: skip `git stash`, `git checkout -- .`, `git reset
  --hard`, `git clean` and rebases of unpushed commits you did not write.
- **Pushing releases.** Every push to `main` runs `.github/workflows/release.yml`, and any
  `feat`/`fix` since the last tag ships a signed build to users. Push only when the user asks.
  Pushing sends every agent's local commits along with yours, so check `git log origin/main..`
  first.

### Building and testing

- `swift test` / `make test` are safe to run concurrently. They share `.build/`, so SwiftPM
  serializes them on its lock — a build "waiting for lock" is another agent, not a hang. Tests
  run against the whole shared tree, so a failure in a file you did not touch is someone else's
  in-progress work: report it rather than fix it.
- Tests must never use the live socket (`~/Library/Application Support/Adrenaline/adrenaline.sock`)
  or the real `UserDefaults` domain. Use a unique `/tmp` socket path and a UUID `suiteName`, as
  `HoldSocketServerTests` and `PreferencesStoreTests` do.
- Build the app into your own output directory so you never overwrite or delete another agent's
  bundle: `make app BUILD_DIR=build/<your-task>`, and run that copy with
  `open build/<your-task>/Adrenaline.app`.

### Installing: `/Applications/Adrenaline.app` is shared

The installed app is live infrastructure. Other agents' harnesses hold it on through the socket
during long tasks, and `make reinstall` kills it — dropping every hold, so the Mac can sleep
mid-task — then replaces it with a bundle of whatever the shared tree holds right now.

- Run `make reinstall` only when the user asks for an installed build.
- Before it, run `/Applications/Adrenaline.app/Contents/Helpers/adrenaline status`; if `holds` is
  non-empty, tell the user who is holding it and let them decide.
- Leave the privileged helper (`/Library/PrivilegedHelperTools/com.tonioriol.adrenaline.helper`)
  and its LaunchDaemon alone unless your task is about them.
