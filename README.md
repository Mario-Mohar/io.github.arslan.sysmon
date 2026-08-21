# SysMon for Omarchy

A lightweight system monitor for the Omarchy desktop shell. Displays CPU, memory, temperature, and disk stats in the bar with click-to-expand detail panels.

## Features

- **Bar widgets:** CPU freq+usage, RAM%, temperature, disk usage
- **Detail panels:** Click any stat to open a full breakdown
- **Keyboard nav:** Arrow keys to switch between panels, Escape to close
- **Configurable:** Hide individual segments, toggle icons, set sample interval

## Requirements

- Omarchy 4.0+ (Quattro)
- Quickshell with `qs.Ui` module

## Install

```bash
omarchy plugin add io.github.arslan.sysmon --enable
```

## Configure

Edit `~/.config/omarchy/shell.json` and add to your bar layout:

```json
{
  "modules": ["io.github.arslan.sysmon"],
  "settings": {
    "interval": 2,
    "showCpu": true,
    "showMemory": true,
    "showTemp": true,
    "showDisk": true,
    "showIcons": true
  }
}
```

## Hotkeys

| Key | Action |
|---|---|
| Left/Right | Switch between stat panels |
| Escape | Close panel |
| `SUPER CTRL V` | Toggle CPU panel |
| `SUPER CTRL B` | Toggle Memory panel |
| `SUPER CTRL T` | Toggle Temperature panel |
| `SUPER CTRL D` | Toggle Disk panel |

## License

MIT
