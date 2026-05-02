# Adrenaline

Keep your Mac awake from the menu bar — even with the lid closed.

**Left-click** the icon to toggle sleep prevention on/off. **Right-click** for options:

| Option | Default | |
|---|---|---|
| Prevent display sleep | ON | Also keeps the display awake |
| Prevent sleep with lid closed | OFF | Requires one-time admin authorization |
| Play lid event sounds | ON | Sound on lid open/close |
| Launch at login | OFF | Start with macOS |

## Install

### Homebrew

```bash
brew tap tonioriol/adrenaline https://github.com/tonioriol/adrenaline.git
brew install --cask tonioriol/adrenaline/adrenaline
```

After the official cask is accepted, you can install with `brew install --cask adrenaline`.

### Direct download

Grab the latest `.zip` from [Releases](https://github.com/tonioriol/adrenaline/releases/latest), unzip, drag to Applications.

### Uninstall

```bash
brew uninstall --zap --cask tonioriol/adrenaline/adrenaline
```

<details>
<summary>Also remove the privileged helper</summary>

```bash
sudo launchctl bootout system/com.tonioriol.adrenaline.helper 2>/dev/null
sudo rm -f /Library/PrivilegedHelperTools/com.tonioriol.adrenaline.helper
sudo rm -f /Library/LaunchDaemons/com.tonioriol.adrenaline.helper.plist
```

</details>

## Build

```bash
make app        # → build/Adrenaline.app
make test
make run
```

## License

[AGPL-3.0](LICENSE)

Inspired by Caffeine and Fermata; no third-party source is vendored in this repository.
