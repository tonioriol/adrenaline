# Cocaine

Personal macOS menu bar app with one on/off icon. When on, it prevents system sleep using public IOKit assertions. Optional preferences can also prevent display sleep, prevent sleep with the lid closed, play lid event sounds, and launch Cocaine at login.

## Safety

Do not put a closed MacBook into a bag with **Prevent sleep with lid closed** enabled. Lid-close sleep prevention can leave the machine running and may cause overheating.

## Build

```bash
make test
make app
```

The app bundle is created at `build/Cocaine.app`.

## Run

```bash
make run
```

The first time you enable **Prevent sleep with lid closed**, macOS asks for admin authorization to install the privileged helper that controls lid-close behavior.

## Behavior

- **Left-click menu bar icon:** toggle Cocaine off ↔ on. While on, your current preferences are enforced.
- **Right-click menu bar icon:** opens a menu with these checkbox preferences. Preference checkbox toggles keep the menu open so you can change multiple settings without reopening it.

  | Preference | Default | What it does |
  |---|---|---|
  | Prevent display sleep | ON | Holds a display-sleep assertion in addition to the no-idle assertion. Mostly meaningful for external displays while the lid is open. |
  | Prevent sleep with lid closed | OFF | Engages the privileged helper to keep the Mac awake when the lid closes. Requires one-time admin authorization and a confirmation alert. |
  | Play lid event sounds | ON | Plays the macOS Hero sound on lid close and Basso on lid open while Cocaine is on and lid-close sleep prevention is enabled. The row is disabled while lid-close sleep prevention is off. |
  | Launch at login | OFF | Registers Cocaine as a macOS login item. The checkbox reflects the actual login-item state reported by macOS. |

- **When Cocaine is off:** all preferences are inert. No assertions are held, no helper calls are made, no lock action fires.
- **When Cocaine is on and lid-close prevention is off:** closing the lid follows native macOS behavior. The Mac may sleep and lock according to your system settings; Cocaine does not force any separate lid-close lock action.
- **When display sleep is allowed:** Cocaine can keep the computer awake while macOS still turns off or locks the display according to your system settings.

## Upgrading from earlier versions

Earlier versions enabled lid-close sleep prevention as part of the single on/off toggle. This version makes lid-close prevention an explicit opt-in — its default after upgrade is **off**. To restore the old behavior, right-click the menu bar icon and check **Prevent sleep with lid closed** once.
