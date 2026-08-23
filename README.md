# SysMon for Omarchy

A lightweight system monitor for the Omarchy desktop shell. It shows four live glance metrics in the bar and opens a richer 7-tab dashboard for CPU, temperature, memory, disk, network, GPU, and processes.

## Features

- **Bar pills:** CPU frequency+usage, RAM usage, CPU temperature, and root disk usage
- **7-tab dashboard:** CPU, Temp, Mem, Disk, Net, GPU, and Process tabs
- **On-demand collector:** `collector.py` runs only while the panel is open and streams JSON snapshots to QML
- **History views:** Sparklines for CPU, temperature, network throughput, and GPU activity
- **Disk tools:** Physical drive list, mounted filesystem gauges, unmounted partition display, mount actions, and SMART health/details
- **Process tools:** Sort, filter, keyboard cursor, detail cards, terminate/kill confirmation, pause/resume actions
- **Keyboard navigation:** Arrow keys, number-key tab jumps, process shortcuts, and Escape behavior that unwinds detail/filter/panel state
- **Theme-aware styling:** Monochrome base with amber/red threshold accents and focused color islands for memory and temperatures

## Requirements

- Omarchy 4.0+ (Quattro)
- Quickshell with `qs.Ui` and `Quickshell.Io`
- Python 3 for the panel collector
- Optional: `smartmontools` for SMART disk health checks. The panel can offer installation through `pkexec pacman` when missing.

## Install

```bash
omarchy plugin add io.github.arslan.sysmon --enable
```

## Configure

The plugin exposes `refreshSeconds`, which controls the panel collector interval and is clamped from 1 to 10 seconds.

```json
{
  "modules": ["io.github.arslan.sysmon"],
  "settings": {
    "refreshSeconds": 1
  }
}
```

The bar sampler runs independently in `SysMonCore.qml` every 2 seconds.

## Tabs

| Tab | Key | Highlights |
|---|---|---|
| CPU | `cpu` | Total/core usage, model/frequency/load details, usage history |
| Temp | `temp` | Core temps, thermal bands, fan/device rows, GPU/NVMe links |
| Mem | `mem` | Memory ring, used/free/cache/swap breakdown |
| Disk | `disk` | Drives, partitions, mounts, SMART, mount actions |
| Net | `net` | Interface rates, RX/TX history, addresses/stat counters |
| GPU | `gpu` | GPU presence, activity, memory/temp where available |
| Process | `proc` | Sortable/filterable process table with signal actions |

## Hotkeys and Keyboard Navigation

| Key | Action |
|---|---|
| Left/Right | Switch dashboard tabs |
| Number keys `1`-`7` | Jump to CPU, Temp, Mem, Disk, Net, GPU, Process |
| Up/Down | Scroll current tab, or move the process cursor in Process tab |
| Enter | Activate the highlighted process row detail |
| Delete | Request terminate for highlighted process |
| Escape | Close process detail, clear filter, or close the panel |
| `s` / `S` in Process | Cycle sort column forward/back |
| `r` in Process | Reverse sort direction |
| `/` or `f` in Process | Focus process filter |
| `g` / `G` in Process | Jump to top/bottom |
| `SUPER CTRL V` | Open CPU tab |
| `SUPER CTRL B` | Open Memory tab |
| `SUPER CTRL T` | Open Temperature tab |
| `SUPER CTRL D` | Open Disk tab |
| `SUPER CTRL N` | Open Network tab |
| `SUPER CTRL G` | Open GPU tab |
| `SUPER CTRL P` | Open Process tab |

## Architecture

- `SysMon.qml` renders the bar pills and loads `Panel.qml`.
- `SysMonCore.qml` samples lightweight bar data from `/proc` and `/sys`.
- `Panel.qml` starts `collector.py --interval <refreshSeconds>` only while open.
- `collector.py` emits one JSON snapshot per line.
- `Panel.qml` stores the latest snapshot, updates history arrays, and exposes data/action helpers to the active tab.
- `tabs/*.qml` contain the seven tab bodies.
- `components/*.qml` contain reusable rows, meters, sparklines, action pills, headers, and shared layout helpers.

## Debugging

```bash
journalctl --user --since '10 min ago' | grep -iE 'qml|sysmon|io.github.arslan.sysmon'

cd ~/.config/omarchy/plugins/io.github.arslan.sysmon
timeout 4 python3 collector.py --interval 1 | head -n 1 | python3 -m json.tool

qmllint Panel.qml SysMon.qml SysMonCore.qml MemRing.qml tabs/*.qml components/*.qml
```

## License

MIT
