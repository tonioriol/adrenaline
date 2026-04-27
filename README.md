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

Signed and notarized release artifacts are produced by GitHub Actions when a version tag such as `v0.1.0` is pushed.

Required repository secrets:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_NOTARYTOOL_PROFILE`

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

- **When Insomnia is off:** all preferences are inert. No assertions are held, no helper calls are made, and native macOS owns lid-close locking and sleep.
- **When Insomnia is on and Prevent display sleep is off:** closing the lid locks immediately if macOS **Require password** is enabled. This mirrors native macOS lid-close behavior and is independent of **Prevent system sleep with lid closed**.
- **When Insomnia is on and Prevent display sleep is on:** Insomnia intentionally keeps the display awake, so it does not run the immediate lid-close lock path.
- **Prevent system sleep with lid closed:** controls whether Insomnia keeps the CPU awake after the lid closes. It does not control whether lid close locks the screen.
- **Require password disabled in macOS:** Insomnia does not force a lock on lid close.

## Upgrading from earlier versions

Earlier versions enabled lid-close sleep prevention as part of the single on/off toggle. This version makes lid-close prevention an explicit opt-in — its default after upgrade is **off**. To restore the old behavior, right-click the menu bar icon and check **Prevent system sleep with lid closed** once.
