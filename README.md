# Cocaine

Personal macOS menu bar app with one on/off icon. When on, it prevents idle sleep using public IOKit assertions. Optional preferences extend that to display sleep, full lid-close sleep prevention, and screen locking on lid close.

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
- **Right-click menu bar icon:** opens a menu with these checkbox preferences (saved across launches):

  | Preference | Default | What it does |
  |---|---|---|
  | Prevent display sleep | ON | Holds a display-sleep assertion in addition to the no-idle assertion. Mostly meaningful for external displays while the lid is open. |
  | Prevent sleep with lid closed | OFF | Engages the privileged helper to keep the Mac awake when the lid closes. Requires one-time admin authorization and a confirmation alert. |
  | Lock screen when lid closes | ON | When lid-close prevention is on, locks your session as soon as the lid closes (Mac stays awake, screen blanks, session locked). |
  | Play lid event sounds | ON | Plays the macOS Hero sound on lid close and Basso on lid open while Cocaine is on. |

- **When Cocaine is off:** all preferences are inert. No assertions are held, no helper calls are made, no lock action fires.
- **When Cocaine is on and lid-close prevention is off:** the Mac sleeps normally on lid close (no sounds, no lock — there is no event to react to).
- **Repair / Install Helper:** appears in the menu when helper setup or communication has failed.

## Upgrading from earlier versions

Earlier versions enabled lid-close sleep prevention as part of the single on/off toggle. This version makes lid-close prevention an explicit opt-in — its default after upgrade is **off**. To restore the old behavior, right-click the menu bar icon and check **Prevent sleep with lid closed** once.
