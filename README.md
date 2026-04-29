# Insomnia

Keep your Mac awake from the menu bar.

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
brew tap tonioriol/insomnia https://github.com/tonioriol/insomnia.git
brew install --cask tonioriol/insomnia/insomnia
```

The full cask name avoids the existing Kong `insomnia` cask.

### Direct download

Grab the latest `.zip` from [Releases](https://github.com/tonioriol/insomnia/releases/latest), unzip, drag to Applications.

### Uninstall

```bash
brew uninstall --zap --cask tonioriol/insomnia/insomnia
```

<details>
<summary>Also remove the privileged helper</summary>

```bash
sudo launchctl bootout system/com.tonioriol.insomnia.helper 2>/dev/null
sudo rm -f /Library/PrivilegedHelperTools/com.tonioriol.insomnia.helper
sudo rm -f /Library/LaunchDaemons/com.tonioriol.insomnia.helper.plist
```

</details>

## Build

```bash
make app        # → build/Insomnia.app
make test
make run
```

## License

[AGPL-3.0](LICENSE)
