# Insomnia Full Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the app, package, helper, resources, tests, CI artifacts, and documentation to Insomnia with lowercase public bundle identifiers under `com.tonioriol.insomnia`.

**Architecture:** Perform the rename in three focused passes: implementation identity, documentation/workspace text, then final verification. Use deterministic scripts with explicit mappings so bundle identifiers, Swift module names, helper labels, preference keys, and release artifacts stay consistent while app behavior remains unchanged.

**Tech Stack:** SwiftPM, Swift 5.9, AppKit, XCTest, Makefile, macOS `codesign`, GitHub Actions, `rg`, `fd`, plist metadata, SMJobBless helper requirements.

---

## File Structure

- Move `Sources/Insomnia/` — main AppKit menu bar executable target.
- Move `Sources/InsomniaCore/` — core library target and public app/helper protocols.
- Move `Sources/InsomniaHelper/` — privileged helper executable target.
- Move `Tests/InsomniaCoreTests/` — XCTest target for the core library.
- Move `Resources/Insomnia/` — app bundle metadata and app icon.
- Move `Resources/InsomniaHelper/` — helper metadata and launchd plist.
- Modify `Package.swift` — package, product, target, dependency, and test names.
- Modify `Makefile` — app/helper executable names, bundle paths, install path, icon path, release zip path, helper label path, and verification target.
- Modify `.github/workflows/release.yml` — release artifact paths and uploaded zip name.
- Modify `Scripts/generate-app-icon.swift` — default output path, temporary iconset name, and error domain.
- Modify source and test Swift files — imports, testable imports, helper protocol/constants names, preference keys, log subsystems, user-visible strings, assertion reasons.
- Modify `README.md`, `NOTICE.md`, `docs/scratch.md`, `.vscode/launch.json`, and `docs/feat/**` — tracked and local text references.
- Update `docs/feat/20260426225736-rename-insomnia/context.md` — task log and execution cursor.

## Task 1: Rename implementation identity

**Files:**
- Modify: `Package.swift`
- Modify: `Makefile`
- Modify: `.github/workflows/release.yml`
- Modify: `Scripts/generate-app-icon.swift`
- Move: source, test, and resource directories listed in File Structure
- Modify: all Swift files under `Sources/Insomnia/`, `Sources/InsomniaCore/`, `Sources/InsomniaHelper/`, and `Tests/InsomniaCoreTests/`
- Modify: plist files under `Resources/Insomnia/` and `Resources/InsomniaHelper/`

- [x] **Step 1: Move source, test, and resource directories**

Run:

```bash
OLD_CAP="$(printf 'C%s' 'ocaine')"
git mv "Sources/${OLD_CAP}" Sources/Insomnia
git mv "Sources/${OLD_CAP}Core" Sources/InsomniaCore
git mv "Sources/${OLD_CAP}Helper" Sources/InsomniaHelper
git mv "Tests/${OLD_CAP}CoreTests" Tests/InsomniaCoreTests
git mv "Resources/${OLD_CAP}" Resources/Insomnia
git mv "Resources/${OLD_CAP}Helper" Resources/InsomniaHelper
git mv "Resources/Insomnia/${OLD_CAP}.icns" Resources/Insomnia/Insomnia.icns
git mv "Sources/InsomniaCore/${OLD_CAP}HelperProtocol.swift" Sources/InsomniaCore/InsomniaHelperProtocol.swift
git mv "Tests/InsomniaCoreTests/${OLD_CAP}HelperConstantsTests.swift" Tests/InsomniaCoreTests/InsomniaHelperConstantsTests.swift
```

Expected: all `git mv` commands exit 0.

- [x] **Step 2: Apply implementation rename mappings**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

old_cap = 'C' + 'ocaine'
old_low = 'c' + 'ocaine'
old_up = 'CO' + 'CAINE'
paths = [
    Path('Package.swift'),
    Path('Makefile'),
    Path('.github/workflows/release.yml'),
    Path('Scripts/generate-app-icon.swift'),
]
paths += sorted(Path('Sources').rglob('*.swift'))
paths += sorted(Path('Tests').rglob('*.swift'))
paths += sorted(Path('Resources').rglob('*.plist'))

replacements = [
    (f'com.tr0n.{old_cap}.Helper', 'com.tonioriol.insomnia.helper'),
    (f'com.tr0n.{old_cap}', 'com.tonioriol.insomnia'),
    (f'{old_cap}HelperProtocol', 'InsomniaHelperProtocol'),
    (f'{old_cap}HelperConstants', 'InsomniaHelperConstants'),
    (f'{old_cap}CoreTests', 'InsomniaCoreTests'),
    (f'{old_cap}Core', 'InsomniaCore'),
    (f'{old_cap}Helper', 'InsomniaHelper'),
    (old_cap, 'Insomnia'),
    (old_low, 'insomnia'),
    (old_up, 'INSOMNIA'),
]

for path in paths:
    text = path.read_text()
    updated = text
    for before, after in replacements:
        updated = updated.replace(before, after)
    if updated != text:
        path.write_text(updated)
PY
```

Expected: command exits 0 and updates implementation files only.

- [x] **Step 3: Confirm key renamed identifiers**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
checks = {
    'Package.swift': ['name: "Insomnia"', '.executable(name: "Insomnia"', '.library(name: "InsomniaCore"', 'name: "InsomniaHelper"', 'name: "InsomniaCoreTests"'],
    'Resources/Insomnia/Info.plist': ['<string>Insomnia</string>', '<string>com.tonioriol.insomnia</string>', '<key>com.tonioriol.insomnia.helper</key>'],
    'Resources/InsomniaHelper/Info.plist': ['<string>com.tonioriol.insomnia.helper</string>', '<string>InsomniaHelper</string>', 'identifier "com.tonioriol.insomnia"'],
    'Resources/InsomniaHelper/launchd.plist': ['<string>com.tonioriol.insomnia.helper</string>', '<key>com.tonioriol.insomnia.helper</key>'],
    'Sources/InsomniaCore/InsomniaHelperProtocol.swift': ['public enum InsomniaHelperConstants', 'public protocol InsomniaHelperProtocol', 'com.tonioriol.insomnia'],
    '.github/workflows/release.yml': ['build/Insomnia.app', 'build/Insomnia.zip', 'build/Insomnia-${GITHUB_REF_NAME}.zip'],
}
for file_name, needles in checks.items():
    text = Path(file_name).read_text()
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise SystemExit(f'{file_name} missing {missing}')
print('renamed identifiers verified')
PY
```

Expected: prints `renamed identifiers verified`.

- [x] **Step 4: Run focused signing tests after rename**

Run:

```bash
swift test --filter InsomniaHelperConstantsTests
```

Expected: PASS with the renamed helper constants tests.

- [x] **Step 5: Commit implementation identity rename**

Run:

```bash
git add Package.swift Makefile .github/workflows/release.yml Scripts/generate-app-icon.swift Sources Tests Resources
git -c commit.gpgsign=false commit -m "refactor: rename app identity to insomnia"
```

Expected: commit succeeds.

## Task 2: Rename documentation and local workspace text

**Files:**
- Modify: `README.md`
- Modify: `NOTICE.md`
- Modify: `docs/feat/**`
- Modify: `docs/scratch.md` if present
- Modify: `.vscode/launch.json` if present
- Modify: `docs/feat/20260426225736-rename-insomnia/context.md`
- Modify: `docs/feat/20260426225736-rename-insomnia/spec.md`
- Modify: `docs/feat/20260426225736-rename-insomnia/plan.md`

- [x] **Step 1: Apply text rename across docs and workspace support files**

Run:

```bash
python3 - <<'PY'
from pathlib import Path

old_cap = 'C' + 'ocaine'
old_low = 'c' + 'ocaine'
old_up = 'CO' + 'CAINE'
roots = [Path('README.md'), Path('NOTICE.md'), Path('docs'), Path('.vscode')]
extra_files = [Path('docs/scratch.md')]
replacements = [
    (f'com.tr0n.{old_cap}.Helper', 'com.tonioriol.insomnia.helper'),
    (f'com.tr0n.{old_cap}', 'com.tonioriol.insomnia'),
    (f'/Applications/{old_cap}.app', '/Applications/Insomnia.app'),
    (f'build/{old_cap}.app', 'build/Insomnia.app'),
    (f'build/{old_cap}.zip', 'build/Insomnia.zip'),
    (f'{old_cap}HelperProtocol', 'InsomniaHelperProtocol'),
    (f'{old_cap}HelperConstants', 'InsomniaHelperConstants'),
    (f'{old_cap}CoreTests', 'InsomniaCoreTests'),
    (f'{old_cap}Core', 'InsomniaCore'),
    (f'{old_cap}Helper', 'InsomniaHelper'),
    (old_cap, 'Insomnia'),
    (old_low, 'insomnia'),
    (old_up, 'INSOMNIA'),
]

candidate_files = []
for root in roots:
    if root.is_file():
        candidate_files.append(root)
    elif root.is_dir():
        candidate_files.extend(path for path in root.rglob('*') if path.is_file())
for path in extra_files:
    if path.is_file() and path not in candidate_files:
        candidate_files.append(path)

for path in sorted(set(candidate_files)):
    if '.git' in path.parts or '.build' in path.parts or 'build' in path.parts:
        continue
    try:
        text = path.read_text()
    except UnicodeDecodeError:
        continue
    updated = text
    for before, after in replacements:
        updated = updated.replace(before, after)
    if updated != text:
        path.write_text(updated)
PY
```

Expected: command exits 0.

- [x] **Step 2: Verify old text tokens are gone from workspace text**

Run:

```bash
OLD_CAP="$(printf 'C%s' 'ocaine')"
OLD_LOW="$(printf 'c%s' 'ocaine')"
OLD_UP="$(printf 'CO%s' 'CAINE')"
rg -n "${OLD_CAP}|${OLD_LOW}|${OLD_UP}" . --glob '!build/**' --glob '!.build/**' --glob '!.git/**'
```

Expected: no matches; `rg` exits 1 with empty output.

- [x] **Step 3: Verify old path tokens are gone from workspace filenames**

Run:

```bash
OLD_CAP="$(printf 'C%s' 'ocaine')"
OLD_LOW="$(printf 'c%s' 'ocaine')"
OLD_UP="$(printf 'CO%s' 'CAINE')"
fd -H . . -E .git -E .build -E build | rg "${OLD_CAP}|${OLD_LOW}|${OLD_UP}"
```

Expected: no matches; `rg` exits 1 with empty output.

- [x] **Step 4: Verify new user-facing docs**

Run:

```bash
rg -n 'Insomnia|build/Insomnia\.app|Insomnia is licensed|launch Insomnia at login' README.md NOTICE.md
```

Expected: output includes the README title, app bundle path, license line, launch-at-login wording, and NOTICE attribution line.

- [x] **Step 5: Commit docs rename**

Run:

```bash
git add README.md NOTICE.md docs .vscode/launch.json
git -c commit.gpgsign=false commit -m "docs: rename project references to insomnia"
```

Expected: commit succeeds. If `.vscode/launch.json` is intentionally untracked and should stay local, leave it modified but do not stage it; then run the same commit without `.vscode/launch.json`.

## Task 3: Final verification and cleanup

**Files:**
- Verify: `Package.swift`
- Verify: `Makefile`
- Verify: `.github/workflows/release.yml`
- Verify: `Resources/Insomnia/Info.plist`
- Verify: `Resources/InsomniaHelper/Info.plist`
- Verify: `Resources/InsomniaHelper/launchd.plist`
- Modify: `docs/feat/20260426225736-rename-insomnia/context.md`
- Modify: `docs/feat/20260426225736-rename-insomnia/plan.md`

- [ ] **Step 1: Clean generated artifacts**

Run:

```bash
make clean
```

Expected: `.build` and `build` are removed.

- [ ] **Step 2: Run full tests**

Run:

```bash
swift test
```

Expected: PASS with the renamed `InsomniaCoreTests` target.

- [ ] **Step 3: Build the app bundle**

Run:

```bash
make app CONFIGURATION=release
```

Expected: PASS when a usable local signing identity is available. The created app bundle path is `build/Insomnia.app`.

- [ ] **Step 4: Build the release zip**

Run:

```bash
make release-zip CONFIGURATION=release
```

Expected: PASS when a usable local signing identity is available and `build/Insomnia.zip` exists.

- [ ] **Step 5: Verify bundle identifiers**

Run:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Insomnia/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/InsomniaHelper/Info.plist
/usr/libexec/PlistBuddy -c 'Print :Label' Resources/InsomniaHelper/launchd.plist
```

Expected output:

```text
com.tonioriol.insomnia
com.tonioriol.insomnia.helper
com.tonioriol.insomnia.helper
```

- [ ] **Step 6: Verify no legacy content tokens remain**

Run:

```bash
OLD_CAP="$(printf 'C%s' 'ocaine')"
OLD_LOW="$(printf 'c%s' 'ocaine')"
OLD_UP="$(printf 'CO%s' 'CAINE')"
rg -n "${OLD_CAP}|${OLD_LOW}|${OLD_UP}" . --glob '!build/**' --glob '!.build/**' --glob '!.git/**'
```

Expected: no matches; `rg` exits 1 with empty output.

- [ ] **Step 7: Verify no legacy path tokens remain**

Run:

```bash
OLD_CAP="$(printf 'C%s' 'ocaine')"
OLD_LOW="$(printf 'c%s' 'ocaine')"
OLD_UP="$(printf 'CO%s' 'CAINE')"
fd -H . . -E .git -E .build -E build | rg "${OLD_CAP}|${OLD_LOW}|${OLD_UP}"
```

Expected: no matches; `rg` exits 1 with empty output.

- [ ] **Step 8: Verify expected Insomnia references exist**

Run:

```bash
rg -n 'Insomnia|insomnia|INSOMNIA' Package.swift Makefile README.md NOTICE.md .github/workflows/release.yml Resources Sources Tests docs | head -80
```

Expected: output shows renamed package, build, docs, bundle ID, helper ID, and test references.

- [ ] **Step 9: Update task memory completion state**

Append one final LOG entry to `docs/feat/20260426225736-rename-insomnia/context.md` with verification evidence and any local-only leftovers, then mark this plan's checkboxes complete.

- [ ] **Step 10: Commit verification record**

Run:

```bash
git add docs/feat/20260426225736-rename-insomnia/context.md docs/feat/20260426225736-rename-insomnia/plan.md
git -c commit.gpgsign=false commit -m "docs: record insomnia rename verification"
```

Expected: commit succeeds.
