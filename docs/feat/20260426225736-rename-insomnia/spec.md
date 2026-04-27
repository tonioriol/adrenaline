# Insomnia Full Rename Spec

## Goal

Rename the app from the legacy app name to Insomnia before public release, with no remaining legacy-name references in tracked source, resources, tests, build scripts, release workflow, or documentation.

## Naming Decisions

- Visible product name: `Insomnia`.
- Swift package name: `Insomnia`.
- Main executable target: `Insomnia`.
- Core library target: `InsomniaCore`.
- Privileged helper target: `InsomniaHelper`.
- Test target: `InsomniaCoreTests`.
- App bundle path: `build/Insomnia.app`.
- App executable: `Contents/MacOS/Insomnia`.
- Helper executable in the app bundle: `Contents/Library/LaunchServices/com.tonioriol.insomnia.helper`.
- App bundle identifier: `com.tonioriol.insomnia`.
- Helper bundle identifier / Mach service / launchd label: `com.tonioriol.insomnia.helper`.
- Resource directory: `Resources/Insomnia/`.
- Helper resource directory: `Resources/InsomniaHelper/`.
- App icon file: `Resources/Insomnia/Insomnia.icns`.
- Default preference keys should move to the `Insomnia.*` namespace.
- Log subsystems should move to `com.tonioriol.insomnia`.

## Scope

The rename must update code, resources, tests, scripts, CI, and docs. It should include file and directory moves where names are part of the public/project identity, not only string replacements.

The current intended destination paths are:

- `Sources/Insomnia/` for the main AppKit menu bar executable target.
- `Sources/InsomniaCore/` for the core library target and shared app/helper protocols.
- `Sources/InsomniaHelper/` for the privileged helper executable target.
- `Tests/InsomniaCoreTests/` for the core library XCTest target.
- `Resources/Insomnia/` for app bundle metadata and icon assets.
- `Resources/InsomniaHelper/` for helper metadata and launchd plist.
- `Resources/Insomnia/Insomnia.icns` for the app icon file.

The icon artwork can stay visually the same for this rename; only file names, generated iconset names, and app metadata need to change.

## Signing and Helper Trust

The SMJobBless trust boundary must be renamed consistently:

- Source constants should become `InsomniaHelperConstants` or another Insomnia-named equivalent.
- Protocol names should become Insomnia-named equivalents.
- App requirement string should use `identifier "com.tonioriol.insomnia"`.
- Helper requirement string should use `identifier "com.tonioriol.insomnia.helper"`.
- Both requirements should keep the Team ID / Developer ID certificate constraint currently used for release signing.
- `Resources/Insomnia/Info.plist`, `Resources/InsomniaHelper/Info.plist`, and `Resources/InsomniaHelper/launchd.plist` must align with the source constants.

## Backward Compatibility

No compatibility migration is required for legacy preference keys, login items, helper labels, or installed helper tools. This is a pre-public rename. After the rename, previous local installs may need manual removal if they still exist under the legacy app identity.

## Documentation and Historical Records

The user explicitly requested no traces of the legacy app name. All tracked Markdown and checked-in text should be renamed, including historical task docs under `docs/feat/`, `README.md`, `NOTICE.md`, and `docs/scratch.md`. Git internal logs and ignored build artifacts are not tracked deliverables and are out of scope.

`README.md` should describe Insomnia, `build/Insomnia.app`, and `Insomnia` behavior. Release docs should refer to `Insomnia-${tag}.zip` and the renamed workflow artifacts.

## CI and Release Artifacts

`.github/workflows/release.yml` should build, verify, notarize, staple, zip, and upload `Insomnia.app`. Final release artifact naming should use `Insomnia-${GITHUB_REF_NAME}.zip`.

`Makefile` should build and sign `Insomnia.app`, create `build/Insomnia.zip`, install to `/Applications/Insomnia.app`, and verify the renamed helper sections.

## Verification

Final verification must include:

- `swift test` passes.
- `make app CONFIGURATION=release` passes with the available local signing identity, or fails only for an explicitly documented signing identity limitation.
- `make release-zip CONFIGURATION=release` creates `build/Insomnia.zip` when signing is available.
- A constructed legacy-token search across tracked workspace text returns no matches.
- `rg -n 'Insomnia|insomnia|INSOMNIA' Package.swift Makefile README.md NOTICE.md .github/workflows/release.yml Resources Sources Tests docs` shows expected renamed references.
- Plist checks confirm the app bundle identifier is `com.tonioriol.insomnia` and helper identifier is `com.tonioriol.insomnia.helper`.

## Non-goals

- No redesign of the app behavior.
- No icon redesign beyond renaming generated filenames/default paths.
- No GitHub publishing, remote creation, or secret setup until the rename is implemented and verified.
- No migration from the legacy local app/helper identity.
