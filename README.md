# Insomnia

macOS menu bar app with one on/off icon. When on, it prevents system sleep using public IOKit assertions. Optional preferences can also prevent display sleep, prevent sleep with the lid closed, play lid event sounds, and launch Insomnia at login.

## Safety

Do not put a closed MacBook into a bag with **Prevent system sleep with lid closed** enabled. Lid-close sleep prevention can leave the machine running and may cause overheating.

## Build

```bash
make test
make app
```

The app bundle is created at `build/Insomnia.app`.

## Release

Releases are fully automated. Push [Conventional Commits](https://www.conventionalcommits.org/) to `main` and CI ships a signed, notarized build whenever the commit history warrants a new version. Squash-merged PR titles count, so PR titles must also follow the convention.

### Commit conventions

| Prefix | Bump | Example |
|---|---|---|
| `feat: ...` | minor | `feat: add right-click About item` |
| `fix: ...` | patch | `fix: release power assertion on reload` |
| `feat!: ...` or footer `BREAKING CHANGE:` | major | `feat!: rename helper protocol method` |
| `docs:`, `chore:`, `refactor:`, `style:`, `test:`, `build:`, `ci:`, `perf:` | no release | `chore: bump dependency` |

### What CI does on release

The flow is driven by [Cocogitto](https://docs.cocogitto.io/), a Rust CLI for conventional commits + semver:

1. `cog bump --auto --dry-run` calculates the next version from commits since the latest tag.
2. PlistBuddy bumps `CFBundleShortVersionString` and `CFBundleVersion` in both [`Resources/Insomnia/Info.plist`](Resources/Insomnia/Info.plist) and [`Resources/InsomniaHelper/Info.plist`](Resources/InsomniaHelper/Info.plist) to the new semver.
3. `cog bump --version X.Y.Z` writes the new section to `CHANGELOG.md`, commits the bumped plists + changelog, and creates a local `vX.Y.Z` tag.
4. The macOS app is built, codesigned (Developer ID), notarized, stapled, and EdDSA-signed.
5. The bumped commit and tag are pushed to `main`. The signed/notarized zip is uploaded as a GitHub Release asset.
6. A new entry is appended to the [gh-pages appcast](https://tonioriol.github.io/insomnia/appcast.xml) so Sparkle clients pick it up on their next check.

While the project is pre-1.0, breaking changes bump minor (`0.1.0` → `0.2.0`) per [Cocogitto's 0.x behavior](https://docs.cocogitto.io/guide/bump.html). The first 1.0.0 release will be cut manually with `cog bump --major` when the public API is stable.

### Manual release

Visit Actions → Release → "Run workflow". The same pipeline runs. Pushing a `v*` tag manually no longer triggers anything.

### Required repository secrets

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_NOTARYTOOL_PROFILE`
- `SPARKLE_ED_PRIVATE_KEY`

## Autoupdate

Insomnia uses [Sparkle](https://sparkle-project.org/) to deliver updates from GitHub Releases. The shipping app polls an appcast feed every 24 hours and prompts to install new versions. The "Automatically install updates" checkbox in the About window switches future updates to silent install on next quit.

- **Appcast feed:** `https://tonioriol.github.io/insomnia/appcast.xml`
- **Hosting:** the `gh-pages` branch, served via GitHub Pages.
- **Trust:** every release zip carries an EdDSA signature in addition to Apple notarization. Sparkle refuses to install if the EdDSA signature does not validate against `SUPublicEDKey` in the running app's Info.plist.

### One-time maintainer setup

These steps happen once before the first Sparkle-aware release:

1. Generate an EdDSA keypair locally with Sparkle's `generate_keys` tool (download `Sparkle-2.7.0.tar.xz` from the Sparkle releases page, run `bin/generate_keys`). Public key is printed; private key is stored in the macOS Keychain.
2. Add a GH Actions repository secret `SPARKLE_ED_PRIVATE_KEY` containing the base64 private key (export from Keychain via `bin/generate_keys -x`).
3. Enable GitHub Pages: repo Settings → Pages → Source = Deploy from a branch → `gh-pages` / `/ (root)`.
4. Create the `gh-pages` branch with a skeleton `appcast.xml`:

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
       <channel>
           <title>Insomnia</title>
           <link>https://github.com/tonioriol/insomnia</link>
           <description>Insomnia macOS app updates</description>
           <language>en</language>
       </channel>
   </rss>
   ```

5. Paste the EdDSA public key into `SUPublicEDKey` in `Resources/Insomnia/Info.plist`.

### Per-release flow

See [Release](#release) for the conventional-commits driven flow that fires CI's signing, notarization, EdDSA signing, GitHub Release creation, and appcast publishing.

### Key rotation

If the EdDSA private key is leaked or rotated:

1. Generate a new keypair.
2. Ship a release that contains the new public key in `SUPublicEDKey` but is signed with the **old** EdDSA key (so existing installs accept it).
3. From the next release onward, sign with the new key.

Standard Sparkle key-rotation playbook.

### Upgrading from 0.1.0

The pre-Sparkle 0.1.0 build does not have Sparkle embedded and therefore cannot auto-update. Users on 0.1.0 must download 0.2.0 once from the GitHub Releases page. After that, autoupdate works for all subsequent versions.

## License

Insomnia is licensed under the GNU Affero General Public License v3.0. See `LICENSE`.

## Run

```bash
make run
```

The first time you enable **Prevent system sleep with lid closed**, macOS asks for admin authorization to install the privileged helper that controls lid-close behavior.

## Behavior

- **Left-click menu bar icon:** toggle Insomnia off ↔ on. While on, your current preferences are enforced.
- **Right-click menu bar icon:** opens a menu with these checkbox preferences. Preference checkbox toggles keep the menu open so you can change multiple settings without reopening it.

  | Preference | Default | What it does |
  |---|---|---|
  | Prevent display sleep | ON | Holds a display-sleep assertion in addition to the no-idle assertion. Mostly meaningful for external displays while the lid is open. |
  | Prevent system sleep with lid closed | OFF | Engages the privileged helper to keep the Mac awake when the lid closes. Requires one-time admin authorization and a confirmation alert. |
  | Play lid event sounds | ON | Plays the macOS Hero sound on lid close and Basso on lid open while Insomnia is on and lid-close sleep prevention is enabled. The row is disabled while lid-close sleep prevention is off. |
  | Launch at login | OFF | Registers Insomnia as a macOS login item. The checkbox reflects the actual login-item state reported by macOS. |

- **About Insomnia:** opens a window with the app version, a "Check for Updates…" button, and an "Automatically install updates" checkbox. With the checkbox off (default), Insomnia prompts before installing each update; with it on, updates download in the background and install on next quit.
- **When Insomnia is off:** all preferences are inert. No assertions are held, no helper calls are made, and native macOS owns lid-close locking and sleep.
- **When Insomnia is on and Prevent display sleep is off:** closing the lid locks immediately if macOS **Require password** is enabled. This mirrors native macOS lid-close behavior and is independent of **Prevent system sleep with lid closed**.
- **When Insomnia is on and Prevent display sleep is on:** Insomnia intentionally keeps the display awake, so it does not run the immediate lid-close lock path.
- **Prevent system sleep with lid closed:** controls whether Insomnia keeps the CPU awake after the lid closes. It does not control whether lid close locks the screen.
- **Require password disabled in macOS:** Insomnia does not force a lock on lid close.

## Upgrading from earlier versions

Earlier versions enabled lid-close sleep prevention as part of the single on/off toggle. This version makes lid-close prevention an explicit opt-in — its default after upgrade is **off**. To restore the old behavior, right-click the menu bar icon and check **Prevent system sleep with lid closed** once.
