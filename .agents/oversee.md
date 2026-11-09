# Oversee — adrenaline

Scope: root agents whose workspace is /Users/tr0n/Code/adrenaline (excluding [TRIAGE] agents and the master triager).

Sources:
- Agents: list_agents for this workspace, active, all statuses, roots only.
- Git: `git status`, `git log origin/main..main` / `main..origin/main` (unpushed or unpulled commits).
- CI and releases: `gh run list -L 5`, `gh release list -L 3`, `gh pr list` (GitHub Actions: Build, Release).
- Installed app: `/Applications/Adrenaline.app` version vs latest release; `adrenaline status` holds.
- Disk: Finder's "available for important usage" (swift one-liner in ~/.agents/AGENTS.md, "Free disk space"); never `df`.

No Slack, mail, Linear or tracker for this project.

Alerts: questions go through the master triager to the owner.
Workflow for new work: plain agent in this checkout following AGENTS.md (commit to main, push only when asked); memory skill for docs/feat.
