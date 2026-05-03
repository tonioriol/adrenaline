# Deliver Adrenaline Rename Through Sparkle Update

## Summary

Existing Sparkle-enabled Insomnia installs must be able to migrate to Adrenaline through the updater instead of requiring a manual reinstall. The cleanest design is a temporary compatibility path: keep the legacy Insomnia appcast alive for 3 months, publish a one-time migration update there, and make that migration update install Adrenaline through a Sparkle package update.

After a user takes the migration update once, the installed app becomes Adrenaline and future updates come from the permanent Adrenaline feed at [`Resources/Adrenaline/Info.plist`](../../../Resources/Adrenaline/Info.plist:40).

## Goals

- Existing Sparkle-enabled Insomnia builds discover a migration update from the legacy Insomnia feed.
- The migration update installs Adrenaline without asking the user to manually download and replace the app.
- After migration, the installed app checks the Adrenaline feed, not the Insomnia feed.
- The legacy Insomnia update path remains available long enough for low-volume users who do not update immediately.
- The compatibility path is temporary and operationally simple.

## Non-goals

- No permanent dual-feed publishing forever.
- No attempt to migrate pre-Sparkle users automatically.
- No effort to preserve a zip-based Sparkle bundle update across a changed app name, app bundle path, and bundle identifier if Sparkle package updates are simpler and safer.
- No indefinite support for the Insomnia appcast after the sunset window.

## Problem

The rename work changed the updater endpoint from the legacy Insomnia feed to the new Adrenaline feed:

- old Sparkle-enabled Insomnia builds check `https://tonioriol.github.io/insomnia/appcast.xml`
- new Adrenaline builds check `https://tonioriol.github.io/adrenaline/appcast.xml`

That means users already running Insomnia will not automatically discover Adrenaline unless the legacy Insomnia appcast is deliberately kept alive as a migration bridge.

There is also a packaging problem. The renamed app changed all of these update identity surfaces:

- app bundle path: `Insomnia.app` → `Adrenaline.app`
- app name: `Insomnia` → `Adrenaline`
- bundle identifier: `com.tonioriol.insomnia` → `com.tonioriol.adrenaline`
- feed URL: `.../insomnia/appcast.xml` → `.../adrenaline/appcast.xml`

Sparkle bundle updates are best when the existing app is still fundamentally the same bundle being replaced in place. For this rename, the update is effectively an installation migration, not a normal in-place bundle swap.

## Evaluated approaches

### 1. Temporary legacy feed + one migration release + package update

Keep the old Insomnia feed alive temporarily, publish one migration item there, and make that migration item install Adrenaline through a package update.

**Pros**
- Clear migration story.
- Low permanent maintenance burden.
- Supports late updaters during the sunset window.
- Uses Sparkle's package-update path, which is intended for custom installation behavior.

**Cons**
- Requires an authorization prompt during migration.
- Adds temporary release/appcast complexity.

### 2. Old feed always points directly at the latest Adrenaline bundle zip

Keep the old Insomnia feed alive but point it straight at normal Adrenaline app bundle updates.

**Pros**
- Fewer moving parts in release automation.

**Cons**
- Risky because Sparkle bundle updates become brittle when app name, app bundle path, and bundle identifier all change.
- Harder to reason about rollback and support issues.

### 3. Publish every future release to both Insomnia and Adrenaline feeds forever

Maintain the old feed indefinitely so old installs never lose the path.

**Pros**
- Maximum backward compatibility.

**Cons**
- Permanent maintenance debt.
- Confusing public distribution story.
- No strong reason to carry the old identity forever given the low user count.

## Chosen design

Use **approach 1**.

### Compatibility window

Keep the legacy Insomnia appcast alive for **3 months** after the first migration release.

Rationale:
- longer than a 1-month window for low-volume users
- avoids permanent dual-feed debt
- simple enough operationally to explain and remove later

At the end of the 3-month window, the Insomnia feed can be replaced with a retirement message or removed entirely.

## Migration mechanics

### Legacy feed behavior

The old Insomnia appcast URL remains available temporarily:

- `https://tonioriol.github.io/insomnia/appcast.xml`

That legacy feed publishes **one migration item** whose only purpose is to move users from Insomnia to Adrenaline.

Important clarification: this is **one migration release**, not a one-day opportunity. The same migration item remains published for the full 3-month window, so a user who updates next week or in 2 months still gets the migration.

### Migration payload type

The migration item uses a **Sparkle package update** rather than a standard app bundle zip update.

Reasoning:
- the rename changes app name and app path
- the rename changes `CFBundleIdentifier`
- the migration needs install/remove behavior, not just bundle replacement

Package updates are the right Sparkle mechanism when installation behavior is custom.

### Migration package responsibilities

The migration package must:

1. install `Adrenaline.app` into `/Applications/Adrenaline.app`
2. remove `/Applications/Insomnia.app`
3. remove the old helper registration and old helper files tied to `com.tonioriol.insomnia.helper`
4. install/register the Adrenaline helper as needed for the new bundle identity
5. leave the resulting installed app configured to use the Adrenaline feed from [`Resources/Adrenaline/Info.plist`](../../../Resources/Adrenaline/Info.plist:40)

The migration package is allowed to prompt for authorization. That is acceptable because the move is an installation migration, not an invisible background patch.

### Post-migration updater behavior

Once Adrenaline is installed, future update checks must use the permanent Adrenaline feed:

- `https://tonioriol.github.io/adrenaline/appcast.xml`

No further compatibility logic is needed in the app after the package migration succeeds.

## Appcast structure

### Canonical feed

The canonical long-term feed remains:

- `https://tonioriol.github.io/adrenaline/appcast.xml`

This feed continues to receive normal Adrenaline release items from the release workflow in [`.github/workflows/release.yml`](../../../.github/workflows/release.yml:192).

### Legacy feed

Create and maintain a second temporary feed for the compatibility window:

- `https://tonioriol.github.io/insomnia/appcast.xml`

This feed does **not** mirror every new Adrenaline release. It is frozen on the migration item for the sunset period.

That makes operational behavior simple:
- old Insomnia users always see the same migration path
- new Adrenaline users always use the normal Adrenaline feed

## Release process impact

The release system needs two update paths:

1. **Normal Adrenaline release path**
   - unchanged in principle
   - build notarized Adrenaline artifact
   - publish Adrenaline release asset
   - append Adrenaline item to `adrenaline/appcast.xml`

2. **One-time migration release path**
   - produce signed/notarized migration package
   - publish it as a release asset
   - generate the temporary `insomnia/appcast.xml` containing the migration item
   - keep that legacy appcast published for 3 months

The migration release can be either:
- a dedicated release tag specifically for migration, or
- a special asset attached to the first Adrenaline release

The important requirement is that the old Insomnia appcast points to the migration package and stays stable during the sunset window.

## UX expectations

- Existing Insomnia users receive a Sparkle update from the old Insomnia feed.
- The migration update may request admin authorization because it is a package install.
- After installation, the user launches Adrenaline instead of Insomnia.
- Future Sparkle updates behave normally from the Adrenaline feed.

## Validation requirements

The implementation must be verified with a realistic installed-app migration test:

1. install a Sparkle-enabled Insomnia build that still points at the old Insomnia feed
2. publish or locally simulate the legacy migration appcast item
3. trigger Sparkle update check from the old app
4. confirm Sparkle offers the migration package
5. complete authorization and installation
6. confirm `/Applications/Adrenaline.app` exists
7. confirm `/Applications/Insomnia.app` is removed
8. confirm the old helper identity is removed and the new helper identity is valid
9. launch Adrenaline and confirm it now checks the Adrenaline feed
10. confirm a subsequent normal Adrenaline update works from the new feed

## Open questions

None for the design direction.

The chosen design is:
- temporary compatibility feed
- 3-month sunset window
- one frozen migration item on the legacy Insomnia feed
- package-based migration into Adrenaline
