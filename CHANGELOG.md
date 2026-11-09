# Changelog

All notable changes to Adrenaline are documented here. Adrenaline follows [Semantic Versioning](https://semver.org/).

- - -

## [v0.7.2](https://github.com/tonioriol/adrenaline/releases/tag/v0.7.2) - 2026-11-09

#### Bug Fixes
- Remember that Adrenaline was on after quitting or restarting

- - -


## [v0.7.1](https://github.com/tonioriol/adrenaline/releases/tag/v0.7.1) - 2026-11-06

#### Bug Fixes
- Never ask for the login password while quitting for restart or logout

- - -


## [v0.7.0](https://github.com/tonioriol/adrenaline/compare/v0.6.0...v0.7.0) - 2026-09-27

#### Features
- Stay unlocked with the lid closed and let the display sleep
- Let other apps keep the Mac awake through a local socket and the `adrenaline` command-line tool
- Support Intel Macs on macOS 10.13 High Sierra and later
- Open the menu with a long press on the menu bar icon

#### Bug Fixes
- Turn the display off when the lid closes with system sleep disabled
- Make lid-close sleep prevention work on Intel Macs running macOS 10.13

- - -

## [v0.6.0](https://github.com/tonioriol/adrenaline/compare/v0.5.0...v0.6.0) - 2026-08-14

#### Features
- Make the lid sound volume override configurable

- - -

## [v0.5.0](https://github.com/tonioriol/adrenaline/compare/v0.4.0...v0.5.0) - 2026-05-27

#### Features
- Add a Prevent disk sleep option

#### Bug Fixes
- Don't mistake SD card readers for disks when detecting the disk type

- - -

## [v0.4.0](https://github.com/tonioriol/adrenaline/compare/v0.3.1...v0.4.0) - 2026-05-22

#### Features
- Play lid open and close sounds at full volume, whatever the system volume

- - -

## [v0.3.1](https://github.com/tonioriol/adrenaline/compare/v0.3.0...v0.3.1) - 2026-05-03

#### Bug Fixes
- Launch Adrenaline automatically after installing the migration package

- - -

## [v0.3.0](https://github.com/tonioriol/adrenaline/compare/v0.2.2...v0.3.0) - 2026-05-03

#### Features
- Add a one-time migration package that moves existing Insomnia users to Adrenaline

- - -

## [v0.2.2](https://github.com/tonioriol/adrenaline/compare/v0.2.1...v0.2.2) - 2026-05-02

#### Changes
- Rename the app from Insomnia to Adrenaline

- - -

## [v0.2.1](https://github.com/tonioriol/adrenaline/compare/v0.2.0...v0.2.1) - 2026-04-28

#### Bug Fixes
- Fix the Homebrew install command

- - -

## [v0.2.0](https://github.com/tonioriol/adrenaline/compare/v0.1.0...v0.2.0) - 2026-04-28

#### Features
- Install with Homebrew

- - -

## [v0.1.0](https://github.com/tonioriol/adrenaline/releases/tag/v0.1.0) - 2026-04-28

First release, as Insomnia.

#### Features
- Keep the Mac awake with one click on the menu bar icon
- Optionally prevent display sleep
- Optionally prevent system sleep with the lid closed
- Lock the screen when the lid closes, following the macOS lock timing
- Play sounds when the lid opens and closes
- Launch at login
- Signed, notarized, with automatic updates

- - -
