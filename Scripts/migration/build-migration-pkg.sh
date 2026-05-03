#!/bin/bash
set -euo pipefail

# Build a signed/notarized migration .pkg that installs Adrenaline.app
# and runs a postinstall script to remove old Insomnia artifacts.
#
# Usage: ./Scripts/migration/build-migration-pkg.sh <version> [code-sign-identity]
# Env:   SPARKLE_ED_PRIVATE_KEY  — EdDSA signing (optional locally, required in CI)
#        APPLE_NOTARYTOOL_PROFILE — notarization (optional locally, required in CI)
#
# Prerequisites: run `make app CONFIGURATION=release` first

VERSION="${1:?Usage: $0 <version> [code-sign-identity]}"
CODE_SIGN_IDENTITY="${2:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Installer/ {print $2; exit}')}"
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

# Build product archive (wraps component for distribution)
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
else
    echo "==> WARNING: No signing identity found, package is unsigned"
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
else
    echo "==> WARNING: SPARKLE_ED_PRIVATE_KEY not set, skipping EdDSA signing"
fi

echo "==> Migration package ready: ${MIGRATION_ZIP}"
