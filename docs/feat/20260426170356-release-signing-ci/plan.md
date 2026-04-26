# Release Signing CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove personal-use framing and add a minimal tag-triggered GitHub Actions release workflow that produces a signed and notarized macOS app zip.

**Architecture:** Keep the existing SwiftPM plus Makefile packaging flow. Add release-specific signing inputs to the Makefile, update the SMJobBless signing requirements for Developer ID, and add one GitHub Actions workflow that imports secrets, builds, signs, notarizes, staples, and uploads the app zip on `v*` tags.

**Tech Stack:** Swift 5.9, SwiftPM, Makefile, macOS `codesign`, `xcrun notarytool`, `xcrun stapler`, GitHub Actions, AGPL-3.0.

---

## File Structure

- Create `LICENSE` — AGPL-3.0 license text.
- Create `.github/workflows/release.yml` — tag-triggered signed/notarized release workflow.
- Modify `README.md` — remove personal wording, document release secrets and tag trigger, link license.
- Modify `NOTICE.md` — remove personal-use wording while preserving attribution.
- Modify `docs/feat/20260424192541-merge-fermatta-caffeine/spec.md` — remove historical personal-use wording.
- Modify `docs/feat/20260424192541-merge-fermatta-caffeine/context.md` — remove historical personal-use wording.
- Modify `docs/feat/20260424192541-merge-fermatta-caffeine/plan.md` — remove historical personal-use wording.
- Modify `Makefile` — support Developer ID release signing without disrupting local build commands.
- Modify `Sources/CocaineCore/CocaineHelperProtocol.swift` — change signing requirement constants to Developer ID certificate shape.
- Modify `Resources/Cocaine/Info.plist` — keep helper requirement aligned with constants.
- Modify `Resources/CocaineHelper/Info.plist` — keep authorized client requirement aligned with constants.
- Modify `Tests/CocaineCoreTests/CocaineHelperConstantsTests.swift` — update signing requirement expectations.

## Task 1: Add AGPL license and clean wording

**Files:**
- Create: `LICENSE`
- Modify: `README.md`
- Modify: `NOTICE.md`
- Modify: `docs/feat/20260424192541-merge-fermatta-caffeine/spec.md`
- Modify: `docs/feat/20260424192541-merge-fermatta-caffeine/context.md`
- Modify: `docs/feat/20260424192541-merge-fermatta-caffeine/plan.md`

- [x] **Step 1: Add AGPL license text**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
Path('LICENSE').write_text('''GNU AFFERO GENERAL PUBLIC LICENSE
Version 3, 19 November 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

This repository is licensed under the GNU Affero General Public License version 3.
See the official license text at https://www.gnu.org/licenses/agpl-3.0.txt.
''')
PY
```

Expected: `LICENSE` exists with the AGPL-3.0 notice and official license URL.

- [x] **Step 2: Remove user-facing personal wording**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
replacements = {
    Path('README.md'): {
        'README opening sentence with personal-only wording': 'README opening sentence without personal-only wording',
    },
    Path('NOTICE.md'): {
        'NOTICE attribution sentence with personal-only wording': 'NOTICE attribution sentence without personal-only wording',
    },
    Path('docs/feat/20260424192541-merge-fermatta-caffeine/spec.md'): {
        'Spec goal sentence with personal-only wording': 'Spec goal sentence without personal-only wording',
        '- Keep the visible product name wording with personal-only qualifier.': '- Keep the visible product name wording without personal-only qualifier.',
        '- Scope sentence with personal-only rationale.': '- Public naming and distribution concerns are out of scope for v1.',
    },
    Path('docs/feat/20260424192541-merge-fermatta-caffeine/context.md'): {
        'Context goal sentence with personal-only wording': 'Context goal sentence without personal-only wording',
        'Context app-name sentence with personal-only wording': 'Context app-name sentence without personal-only wording',
    },
    Path('docs/feat/20260424192541-merge-fermatta-caffeine/plan.md'): {
        'Plan goal sentence with personal-only wording': 'Plan goal sentence without personal-only wording',
        'NOTICE attribution sentence with personal-only wording': 'NOTICE attribution sentence without personal-only wording',
    },
}
for path, changes in replacements.items():
    text = path.read_text()
    for old, new in changes.items():
        if old not in text:
            raise SystemExit(f'missing expected text in {path}: {old}')
        text = text.replace(old, new)
    path.write_text(text)
PY
```

Expected: command exits 0.

- [x] **Step 3: Add README license and release notes**

Insert these sections after the Build section in `README.md`:

```markdown
## Release

Signed and notarized release artifacts are produced by GitHub Actions when a version tag such as `v0.1.0` is pushed.

Required repository secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_NOTARYTOOL_PROFILE`

## License

Cocaine is licensed under the GNU Affero General Public License v3.0. See `LICENSE`.
```

- [x] **Step 4: Verify wording cleanup**

Run:

```bash
rg -n '<personal-only wording pattern>' . --glob '*.md'
```

Expected: no matches.

- [x] **Step 5: Commit wording and license**

Run:

```bash
git add LICENSE README.md NOTICE.md docs/feat/20260424192541-merge-fermatta-caffeine/spec.md docs/feat/20260424192541-merge-fermatta-caffeine/context.md docs/feat/20260424192541-merge-fermatta-caffeine/plan.md
git -c commit.gpgsign=false commit -m "docs: prepare project for public release"
```

Expected: commit succeeds.

## Task 2: Update Developer ID signing requirements

**Files:**
- Modify: `Sources/CocaineCore/CocaineHelperProtocol.swift`
- Modify: `Resources/Cocaine/Info.plist`
- Modify: `Resources/CocaineHelper/Info.plist`
- Modify: `Tests/CocaineCoreTests/CocaineHelperConstantsTests.swift`

- [ ] **Step 1: Update source signing requirement constants**

In `Sources/CocaineCore/CocaineHelperProtocol.swift`, replace the two signing requirement constants with Developer ID Application requirements:

```swift
    public static let appCodeSigningRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine\" and certificate leaf[subject.OU] = \"A79T83GM42\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
    public static let helperCodeSigningRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine.Helper\" and certificate leaf[subject.OU] = \"A79T83GM42\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
```

Expected: requirements no longer mention `Apple Development`.

- [ ] **Step 2: Update plist signing requirements**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
old_helper = 'anchor apple generic and identifier "com.tr0n.Cocaine.Helper" and certificate leaf[subject.CN] = "Apple Development: tonioriol@me.com (A79T83GM42)" and certificate 1[field.1.2.840.113635.100.6.2.1] exists'
new_helper = 'anchor apple generic and identifier "com.tr0n.Cocaine.Helper" and certificate leaf[subject.OU] = "A79T83GM42" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists'
old_app = 'anchor apple generic and identifier "com.tr0n.Cocaine" and certificate leaf[subject.CN] = "Apple Development: tonioriol@me.com (A79T83GM42)" and certificate 1[field.1.2.840.113635.100.6.2.1] exists'
new_app = 'anchor apple generic and identifier "com.tr0n.Cocaine" and certificate leaf[subject.OU] = "A79T83GM42" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists'
for path, pairs in {
    Path('Resources/Cocaine/Info.plist'): [(old_helper, new_helper)],
    Path('Resources/CocaineHelper/Info.plist'): [(old_app, new_app)],
}.items():
    text = path.read_text()
    for old, new in pairs:
        if old not in text:
            raise SystemExit(f'missing expected requirement in {path}')
        text = text.replace(old, new)
    path.write_text(text)
PY
```

Expected: command exits 0.

- [ ] **Step 3: Update signing tests**

In `Tests/CocaineCoreTests/CocaineHelperConstantsTests.swift`, update expected strings to:

```swift
    private let expectedAppRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine\" and certificate leaf[subject.OU] = \"A79T83GM42\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
    private let expectedHelperRequirement = "anchor apple generic and identifier \"com.tr0n.Cocaine.Helper\" and certificate leaf[subject.OU] = \"A79T83GM42\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
```

Expected: test expectations match source constants.

- [ ] **Step 4: Run focused signing tests**

Run:

```bash
swift test --filter CocaineHelperConstantsTests
```

Expected: PASS.

- [ ] **Step 5: Commit signing requirement updates**

Run:

```bash
git add Sources/CocaineCore/CocaineHelperProtocol.swift Resources/Cocaine/Info.plist Resources/CocaineHelper/Info.plist Tests/CocaineCoreTests/CocaineHelperConstantsTests.swift
git -c commit.gpgsign=false commit -m "build: use developer id signing requirements"
```

Expected: commit succeeds.

## Task 3: Add tag-triggered GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Modify: `Makefile`

- [ ] **Step 1: Add release packaging variables to Makefile**

Update `Makefile` so `CODE_SIGN_IDENTITY` can be passed from CI and add a `release-zip` target:

```makefile
RELEASE_ZIP ?= $(BUILD_DIR)/Cocaine.zip

.PHONY: test build generate-app-icon app sign release-zip reinstall run clean verify-helper-sections

release-zip: app
	rm -f $(RELEASE_ZIP)
	ditto -c -k --keepParent $(APP_DIR) $(RELEASE_ZIP)
```

Keep the existing `sign` target order: helper first, app second.

- [ ] **Step 2: Create release workflow**

Create `.github/workflows/release.yml` with:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build-sign-notarize:
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Import Developer ID certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.APPLE_DEVELOPER_ID_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ runner.temp }}/keychain-password
        run: |
          set -euo pipefail
          echo "$(uuidgen)" > "$KEYCHAIN_PASSWORD"
          security create-keychain -p "$(cat "$KEYCHAIN_PASSWORD")" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$(cat "$KEYCHAIN_PASSWORD")" build.keychain
          security set-keychain-settings -lut 21600 build.keychain
          echo "$CERTIFICATE_BASE64" | base64 --decode > certificate.p12
          security import certificate.p12 -k build.keychain -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$(cat "$KEYCHAIN_PASSWORD")" build.keychain
          security find-identity -v -p codesigning build.keychain

      - name: Configure notarytool profile
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
          APPLE_NOTARYTOOL_PROFILE: ${{ secrets.APPLE_NOTARYTOOL_PROFILE }}
        run: |
          set -euo pipefail
          xcrun notarytool store-credentials "$APPLE_NOTARYTOOL_PROFILE" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_SPECIFIC_PASSWORD"

      - name: Build signed app
        env:
          CODE_SIGN_IDENTITY: Developer ID Application
        run: |
          set -euo pipefail
          make release-zip CONFIGURATION=release CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
          codesign --verify --deep --strict --verbose=2 build/Cocaine.app
          spctl --assess --type execute --verbose=4 build/Cocaine.app

      - name: Notarize app zip
        env:
          APPLE_NOTARYTOOL_PROFILE: ${{ secrets.APPLE_NOTARYTOOL_PROFILE }}
        run: |
          set -euo pipefail
          xcrun notarytool submit build/Cocaine.zip --keychain-profile "$APPLE_NOTARYTOOL_PROFILE" --wait
          xcrun stapler staple build/Cocaine.app
          xcrun stapler validate build/Cocaine.app
          rm -f build/Cocaine.zip
          ditto -c -k --keepParent build/Cocaine.app build/Cocaine-${GITHUB_REF_NAME}.zip

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/Cocaine-${{ github.ref_name }}.zip
```

- [ ] **Step 3: Commit workflow and Makefile changes**

Run:

```bash
git add Makefile .github/workflows/release.yml
git -c commit.gpgsign=false commit -m "ci: publish signed notarized releases"
```

Expected: commit succeeds.

## Task 4: Final verification

**Files:**
- Verify: `README.md`
- Verify: `.github/workflows/release.yml`
- Verify: signing sources and plists

- [ ] **Step 1: Run full tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 2: Build release app locally**

Run:

```bash
make app CONFIGURATION=release
```

Expected: PASS if a matching local Developer ID identity is installed; otherwise fail only because the identity is unavailable.

- [ ] **Step 3: Verify no personal-use wording remains**

Run:

```bash
rg -n '<personal-only wording pattern>' . --glob '*.md'
```

Expected: no matches.

- [ ] **Step 4: Verify workflow references all required secrets**

Run:

```bash
rg -n 'APPLE_DEVELOPER_ID_CERTIFICATE_BASE64|APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD|APPLE_ID|APPLE_TEAM_ID|APPLE_APP_SPECIFIC_PASSWORD|APPLE_NOTARYTOOL_PROFILE' .github/workflows/release.yml README.md
```

Expected: all six secret names appear in both workflow or README documentation as appropriate.

- [ ] **Step 5: Update task memory and commit if needed**

Append a final LOG entry to `docs/feat/20260426170356-release-signing-ci/context.md`, then run:

```bash
git add docs/feat/20260426170356-release-signing-ci/context.md
git -c commit.gpgsign=false commit -m "docs: record release ci verification"
```

Expected: commit succeeds if context changed.
