# Cocaine

Personal macOS menu bar app with one on/off icon. When on, it prevents ordinary sleep and lid-close sleep. When off, it restores normal sleep behavior.

## Safety

Do not put a closed MacBook into a bag while Cocaine is on. Lid-close sleep prevention can leave the machine running and may cause overheating.

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

The first activation may request admin authorization to install the privileged helper.

## Behavior

- Left-click menu bar icon: toggle off/on.
- Off: normal sleep behavior.
- On: ordinary sleep and lid-close sleep are prevented.
- Right-click menu: About, helper repair when needed, Quit.
