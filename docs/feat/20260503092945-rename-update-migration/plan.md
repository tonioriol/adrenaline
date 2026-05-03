# Rename Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Sparkle package-based migration so old Insomnia installs can update to Adrenaline through the autoupdater, with a 3-month legacy feed window.

**Architecture:** Create a new `tonioriol/insomnia` GitHub repo to host the legacy gh-pages appcast (the rename broke the old URL). Build a signed/notarized macOS .pkg that installs Adrenaline.app, removes Insomnia.app and old helper artifacts. Publish the .pkg as a migration release and serve it from the legacy appcast. Fix the adrenaline gh-pages appcast metadata that still says "Insomnia".

**Tech Stack:** macOS `pkgbuild`/`productbuild`, Sparkle EdDSA signing, `codesign`, `notarytool`, GitHub CLI, GitHub Pages, Make.

---

## File structure and responsibilities

- `Makefile` — new `migration-pkg` target to build the .pkg installer
- `Scripts/migration/postinstall` — pkg postinstall script that removes old Insomnia.app and helper artifacts
- `Scripts/migration/build-migration-pkg.sh` — builds, signs, notarizes the migration .pkg and wraps it in a .zip
- `.github/workflows/release.yml` — extended to publish migration appcast entry to the legacy insomnia repo's gh-pages
- `adrenaline` repo gh-pages `appcast.xml` — fix metadata (title, link, description) from "Insomnia" to "Adrenaline"
- NEW `insomnia` repo gh-pages `appcast.xml` — frozen legacy feed with one migration item pointing to the .pkg

---

### Task 1: Fix the adrenaline gh-pages appcast metadata

The current appcast.xml on gh-pages still says "Insomnia" in `<title>`, `<link>`, `<description>` and individual item titles. Fix it to say "Adrenaline".

**Files:**
- Modify: gh-pages branch `appcast.xml` (via git clone/push)

- [ ] **Step 1: Clone adrenaline gh-pages and inspect**

```bash
cd /tmp && rm -rf adrenaline-ghpages
git clone --depth 1 --branch gh-pages git@github.com:tonioriol/adrenaline.git adrenaline-ghpages
cd adrenaline-ghpages
cat appcast.xml
```

Expected: appcast.xml with "Insomnia" in channel title/link/description and item titles.

- [ ] **Step 2: Update channel metadata and item titles to Adrenaline**

Use `sd` to replace the channel-level metadata and item titles:

```bash
cd /tmp/adrenaline-ghpages

# Channel metadata
sd '<title>Insomnia</title>' '<title>Adrenaline</title>' appcast.xml
sd '<link>https://github.com/tonioriol/insomnia</link>' '<link>https://github.com/tonioriol/adrenaline</link>' appcast.xml
sd '<description>Insomnia macOS app updates</description>' '<description>Adrenaline macOS app updates</description>' appcast.xml

# Item titles: "Insomnia X.Y.Z" → "Adrenaline X.Y.Z"
sd '<title>Insomnia ' '<title>Adrenaline ' appcast.xml

# Verify
head -10 appcast.xml
rg 'Insomnia' appcast.xml || echo "No remaining Insomnia references in metadata"
```

Expected: channel title/link/description say "Adrenaline", item titles say "Adrenaline X.Y.Z". Old commit links inside `<description>` CDATA still reference `tonioriol/insomnia` which is fine (GitHub redirects).

- [ ] **Step 3: Commit and push**

```bash
cd /tmp/adrenaline-ghpages
git config user.name "Toni Oriol"
git config user.email "toni@tonioriol.com"
git add appcast.xml
git commit -m "fix: rename appcast metadata from Insomnia to Adrenaline"
git push origin gh-pages
```

Expected: push succeeds. `https://tonioriol.github.io/adrenaline/appcast.xml` now shows Adrenaline titles.

- [ ] **Step 4: Verify live feed**

```bash
sleep 30  # wait for GitHub Pages cache
curl -fsSL https://tonioriol.github.io/adrenaline/appcast.xml | head -10
```

Expected: `<title>Adrenaline</title>` in the output.

- [ ] **Step 5: Commit**

No repo-level commit needed — this was a gh-pages-only change.

---

### Task 2: Create migration package postinstall script

The .pkg postinstall script runs as root after macOS Installer copies Adrenaline.app into /Applications/. It removes the old Insomnia.app and its helper artifacts.

**Files:**
- Create: `Scripts/migration/postinstall`

- [ ] **Step 1: Create the postinstall script**

```bash
#!/bin/bash
set -euo pipefail

# This script runs as root after the pkg installer places Adrenaline.app
# into /Applications/. It removes the old Insomnia app and helper.

OLD_APP="/Applications/Insomnia.app"
OLD_HELPER_ID="com.tonioriol.insomnia.helper"
OLD_HELPER_BINARY="/Library/PrivilegedHelperTools/${OLD_HELPER_ID}"
OLD_HELPER_PLIST="/Library/LaunchDaemons/${OLD_HELPER_ID}.plist"

# Unload and remove old privileged helper
if launchctl print "system/${OLD_HELPER_ID}" &>/dev/null; then
    launchctl bootout "system/${OLD_HELPER_ID}" 2>/dev/null || true
fi
rm -f "${OLD_HELPER_BINARY}"
rm -f "${OLD_HELPER_PLIST}"

# Remove old app bundle
if [ -d "${OLD_APP}" ]; then
    rm -rf "${OLD_APP}"
fi

# Clean old Sparkle preferences so the new app doesn't inherit stale state
defaults delete com.tonioriol.insomnia SULastCheckTime 2>/dev/null || true
defaults delete com.tonioriol.insomnia SUUpdateRelaunchingMarker 2>/dev/null || true

exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x Scripts/migration/postinstall
```

- [ ] **Step 3: Commit**

```bash
git add Scripts/migration/postinstall
git commit -m "feat: add migration postinstall to remove old Insomnia artifacts"
```

---

### Task 3: Create migration package build script

This script builds a signed/notarized .pkg that installs Adrenaline.app and runs the postinstall cleanup. It also wraps the .pkg in a .zip and signs it with Sparkle's EdDSA key.

**Files:**
- Create: `Scripts/migration/build-migration-pkg.sh`
- Modify: `Makefile` (add `migration-pkg` target)

- [ ] **Step 1: Create the build script**

```bash
#!/bin/bash
set -euo pipefail

# Usage: ./Scripts/migration/build-migration-pkg.sh <version> [code-sign-identity]
# Env:   SPARKLE_ED_PRIVATE_KEY (required for EdDSA signing)
#        APPLE_NOTARYTOOL_PROFILE (required for notarization)
#
# Prerequisites: run `make app CONFIGURATION=release` first

VERSION="${1:?Usage: $0 <version> [code-sign-identity]}"
CODE_SIGN_IDENTITY="${2:-$(security find-identity -v -p codesigning | awk -F'"' '/B65K228Z97/ {print $2; exit}')}"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/Adrenaline.app"
PKG_DIR="${BUILD_DIR}/migration-pkg"
COMPONENT_PKG="${PKG_DIR}/AdrenalineComponent.pkg"
MIGRATION_PKG="${PKG_DIR}/Adrenaline-migration-v${VERSION}.pkg"
MIGRATION_ZIP="${BUILD_DIR}/Adrenaline-migration-v${VERSION}.zip"
SCRIPTS_DIR="Scripts/migration"

if [ ! -d "${APP_DIR}" ]; then
    echo "ERROR: ${APP_DIR} not found. Run 'make app CONFIGURATION=release' first." >&2
    exit 1
fi

echo "==> Building migration package v${VERSION}"

# Clean
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"

# Build component package (installs Adrenaline.app to /Applications/)
pkgbuild \
    --root "${APP_DIR}" \
    --install-location "/Applications/Adrenaline.app" \
    --scripts "${SCRIPTS_DIR}" \
    --identifier "com.tonioriol.adrenaline.migration" \
    --version "${VERSION}" \
    "${COMPONENT_PKG}"

# Build product archive (wraps component + adds title/background for Installer UI)
productbuild \
    --package "${COMPONENT_PKG}" \
    --identifier "com.tonioriol.adrenaline.migration" \
    --version "${VERSION}" \
    "${MIGRATION_PKG}"

# Sign the package with Developer ID Installer
if [ -n "${CODE_SIGN_IDENTITY}" ]; then
    productsign \
        --sign "${CODE_SIGN_IDENTITY}" \
        "${MIGRATION_PKG}" \
        "${MIGRATION_PKG}.signed"
    mv "${MIGRATION_PKG}.signed" "${MIGRATION_PKG}"
    echo "==> Signed package with: ${CODE_SIGN_IDENTITY}"
fi

# Notarize
if [ -n "${APPLE_NOTARYTOOL_PROFILE:-}" ]; then
    echo "==> Notarizing..."
    xcrun notarytool submit "${MIGRATION_PKG}" \
        --keychain-profile "${APPLE_NOTARYTOOL_PROFILE}" --wait
    xcrun stapler staple "${MIGRATION_PKG}"
    echo "==> Notarization complete"
fi

# Wrap in zip for Sparkle delivery
rm -f "${MIGRATION_ZIP}"
ditto -c -k --keepParent "${MIGRATION_PKG}" "${MIGRATION_ZIP}"

# Sign with EdDSA for Sparkle
if [ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]; then
    SPARKLE_VERSION=$(python3 -c "
import json
with open('Package.resolved') as f:
    data = json.load(f)
for pin in data['pins']:
    if pin['identity'] == 'sparkle':
        print(pin['state']['version'])
        break
")
    SIGN_UPDATE_DIR=$(mktemp -d)
    curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
        | tar -xJf - -C "${SIGN_UPDATE_DIR}" "./bin/sign_update"
    SIG_AND_LEN=$("${SIGN_UPDATE_DIR}/bin/sign_update" \
        --ed-key-file <(printf "%s" "${SPARKLE_ED_PRIVATE_KEY}") \
        "${MIGRATION_ZIP}")
    rm -rf "${SIGN_UPDATE_DIR}"
    echo "==> EdDSA signature: ${SIG_AND_LEN}"
    echo "${SIG_AND_LEN}" > "${BUILD_DIR}/migration-sparkle-sig.txt"
fi

echo "==> Migration package ready: ${MIGRATION_ZIP}"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x Scripts/migration/build-migration-pkg.sh
```

- [ ] **Step 3: Add Makefile target**

Add to `Makefile` after the `release-zip` target:

```make
migration-pkg: app
	./Scripts/migration/build-migration-pkg.sh $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Adrenaline/Info.plist) "$(CODE_SIGN_IDENTITY)"
```

- [ ] **Step 4: Commit**

```bash
git add Scripts/migration/build-migration-pkg.sh Makefile
git commit -m "feat: add migration package build script and Makefile target"
```

---

### Task 4: Create legacy insomnia repo with gh-pages

The old `tonioriol.github.io/insomnia/appcast.xml` URL is dead because the repo was renamed. Create a new `tonioriol/insomnia` repo with a gh-pages branch serving a frozen legacy appcast that points to the migration package.

**Files:**
- New repo: `tonioriol/insomnia` with gh-pages branch containing `appcast.xml`

- [ ] **Step 1: Create the insomnia repo via GitHub CLI**

```bash
gh repo create tonioriol/insomnia --public --description "Legacy update feed — redirects Insomnia users to Adrenaline" --clone=false
```

Expected: repo created. This may break the GitHub redirect from the old renamed repo, which is fine.

- [ ] **Step 2: Set up gh-pages with migration appcast**

The appcast version must be higher than any existing Insomnia version (latest was 0.2.2). Use the current Adrenaline version.

```bash
cd /tmp && rm -rf insomnia-legacy
mkdir insomnia-legacy && cd insomnia-legacy
git init
git checkout --orphan gh-pages

# We'll populate the actual appcast.xml content after building the migration
# package (Task 5), but create the structure now with a placeholder version
# that will be replaced.
cat > appcast.xml << 'APPCAST_EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Insomnia → Adrenaline Migration</title>
        <link>https://github.com/tonioriol/adrenaline</link>
        <description>This feed migrates Insomnia to Adrenaline. After updating, future updates come from the Adrenaline feed.</description>
        <language>en</language>
        <!-- Migration item will be inserted here after the package is built -->
    </channel>
</rss>
APPCAST_EOF

cat > README.md << 'EOF'
# Legacy Insomnia Update Feed

This repo exists solely to serve `https://tonioriol.github.io/insomnia/appcast.xml` for old Insomnia installs that haven't migrated to [Adrenaline](https://github.com/tonioriol/adrenaline) yet.

The feed contains a single migration update that installs Adrenaline and removes Insomnia. After migration, future updates come from the Adrenaline feed.

This repo will be archived approximately 3 months after the migration release.
EOF

git add appcast.xml README.md
git config user.name "Toni Oriol"
git config user.email "toni@tonioriol.com"
git commit -m "init: legacy migration feed for Insomnia → Adrenaline"
git remote add origin git@github.com:tonioriol/insomnia.git
git push -u origin gh-pages
```

Expected: push succeeds. GitHub Pages will serve `tonioriol.github.io/insomnia/appcast.xml`.

- [ ] **Step 3: Enable GitHub Pages on the repo**

```bash
gh api repos/tonioriol/insomnia/pages -X POST -f source.branch=gh-pages -f source.path="/" 2>/dev/null || echo "Pages may auto-enable from gh-pages branch"
```

- [ ] **Step 4: Verify the legacy URL works**

```bash
sleep 60  # GitHub Pages propagation
curl -sI https://tonioriol.github.io/insomnia/appcast.xml | head -5
```

Expected: HTTP 200.

---

### Task 5: Build, publish, and wire up the migration release

Build the migration .pkg locally, publish it as a GitHub release asset, then update both appcast feeds.

**Files:**
- Modify: legacy insomnia repo gh-pages `appcast.xml`
- GitHub release: new release asset on `tonioriol/adrenaline`

- [ ] **Step 1: Build the signed app**

```bash
cd /Users/tr0n/Code/adrenaline
make app CONFIGURATION=release
codesign --verify --deep --strict --verbose=2 build/Adrenaline.app
```

Expected: build succeeds, codesign verifies.

- [ ] **Step 2: Build the migration package**

```bash
make migration-pkg CONFIGURATION=release
ls -la build/Adrenaline-migration-v*.zip
cat build/migration-sparkle-sig.txt
```

Expected: migration .zip exists, EdDSA signature file exists.

- [ ] **Step 3: Create a GitHub release with the migration asset**

```bash
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Adrenaline/Info.plist)
gh release create "v${VERSION}-migration" \
    --repo tonioriol/adrenaline \
    --title "v${VERSION} Migration (Insomnia → Adrenaline)" \
    --notes "One-time migration package for existing Insomnia users. After installing, future updates come from the Adrenaline feed automatically." \
    "build/Adrenaline-migration-v${VERSION}.zip"
```

Expected: release created with the migration zip attached.

- [ ] **Step 4: Update the legacy insomnia appcast with the migration item**

```bash
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Adrenaline/Info.plist)
SIG_AND_LEN=$(cat build/migration-sparkle-sig.txt)
DOWNLOAD_URL="https://github.com/tonioriol/adrenaline/releases/download/v${VERSION}-migration/Adrenaline-migration-v${VERSION}.zip"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

cd /tmp && rm -rf insomnia-legacy-update
git clone --depth 1 --branch gh-pages git@github.com:tonioriol/insomnia.git insomnia-legacy-update
cd insomnia-legacy-update

cat > appcast.xml << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Insomnia → Adrenaline Migration</title>
        <link>https://github.com/tonioriol/adrenaline</link>
        <description>This feed migrates Insomnia to Adrenaline.</description>
        <language>en</language>
        <item>
            <title>Migrate to Adrenaline ${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
            <description><![CDATA[<p>Insomnia has been renamed to <strong>Adrenaline</strong>.</p><p>This update installs Adrenaline and removes the old Insomnia app. Future updates will come from the Adrenaline feed automatically.</p>]]></description>
            <enclosure url="${DOWNLOAD_URL}"
                       type="application/octet-stream"
                       sparkle:installationType="package"
                       ${SIG_AND_LEN} />
        </item>
    </channel>
</rss>
APPCAST_EOF

git config user.name "Toni Oriol"
git config user.email "toni@tonioriol.com"
git add appcast.xml
git commit -m "appcast: migration to Adrenaline v${VERSION}"
git push origin gh-pages
```

Expected: legacy feed now contains the migration item.

- [ ] **Step 5: Verify legacy feed is live**

```bash
sleep 30
curl -fsSL https://tonioriol.github.io/insomnia/appcast.xml
```

Expected: appcast with migration item, correct download URL, installationType="package".

- [ ] **Step 6: Commit migration scripts to adrenaline repo**

All migration infrastructure files should already be committed from Tasks 2-3. Verify:

```bash
cd /Users/tr0n/Code/adrenaline
git log --oneline -5
```

---

### Task 6: End-to-end verification

Verify the full migration path works by simulating an old Insomnia install.

- [ ] **Step 1: Download an old Insomnia release**

```bash
# Get the last Insomnia-named release (v0.2.0 was last before rename)
curl -fsSL -o /tmp/Insomnia-test.zip \
    "https://github.com/tonioriol/adrenaline/releases/download/v0.2.0/Insomnia-v0.2.0.zip"
```

If v0.2.0 Insomnia zip is not available (releases may have been renamed), use whichever old release is still downloadable.

- [ ] **Step 2: Install the old Insomnia build**

```bash
cd /tmp
ditto -x -k Insomnia-test.zip .
# If extracted app is Insomnia.app, install it
cp -R Insomnia.app /Applications/Insomnia.app 2>/dev/null || cp -R Adrenaline.app /Applications/Insomnia.app
```

- [ ] **Step 3: Verify the old app checks the legacy feed**

Launch `/Applications/Insomnia.app` and trigger Check for Updates. Observe in Console.app (filter by "Insomnia" or "Sparkle") that it checks `tonioriol.github.io/insomnia/appcast.xml`.

- [ ] **Step 4: Confirm migration update is offered**

Sparkle should find the migration update and offer to install it. Accept the update (will prompt for admin password since it's a package install).

- [ ] **Step 5: Verify post-migration state**

```bash
# Adrenaline installed
ls -la /Applications/Adrenaline.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/Adrenaline.app/Contents/Info.plist

# Old Insomnia removed
ls /Applications/Insomnia.app 2>&1 || echo "Insomnia.app removed ✓"

# Old helper removed
ls /Library/PrivilegedHelperTools/com.tonioriol.insomnia.helper 2>&1 || echo "Old helper removed ✓"
ls /Library/LaunchDaemons/com.tonioriol.insomnia.helper.plist 2>&1 || echo "Old helper plist removed ✓"
```

Expected: Adrenaline installed with `com.tonioriol.adrenaline` bundle ID, old Insomnia artifacts gone.

- [ ] **Step 6: Verify Adrenaline uses the new feed**

Launch `/Applications/Adrenaline.app`, trigger Check for Updates, verify in Console.app it checks `tonioriol.github.io/adrenaline/appcast.xml`.

- [ ] **Step 7: Clean up test install**

```bash
rm -rf /Applications/Adrenaline.app
rm -rf /Applications/Insomnia.app
sudo launchctl bootout system/com.tonioriol.adrenaline.helper 2>/dev/null || true
sudo rm -f /Library/PrivilegedHelperTools/com.tonioriol.adrenaline.helper
sudo rm -f /Library/LaunchDaemons/com.tonioriol.adrenaline.helper.plist
```
