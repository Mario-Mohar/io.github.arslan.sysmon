# SysMon for Omarchy

Four calm metrics in the bar. One keyboard-friendly dashboard for everything else.

A lightweight system monitor for the Omarchy desktop shell — CPU, temperature, memory, disk, network, GPU, and processes.

Inspired by [omarchy-vitals](https://github.com/Woogy7/omarchy-vitals) by Woogy7, with substantial original work on top.

Screenshots: [screenshots/README.md](screenshots/README.md)

## Features

### Bar widget

- Four live glance pills: CPU (frequency + usage), RAM, CPU temperature, and root disk usage
- Lightweight sampler (`SysMonCore.qml`) reads `/proc` and `/sys` every 2 seconds with minimal overhead
- Theme-aware styling: monochrome base with amber/red threshold accents

### Panel dashboard

- **7 tabs:** CPU, Temp, Mem, Disk, Net, GPU, and Process — loaded lazily via `Loader`; only the active tab runs delegates
- **On-demand collector:** `collector.py` starts when the panel opens, emits one JSON snapshot per line, and stops on close
- **History views:** Sparklines for CPU, temperature, network throughput, and GPU activity
- **Memory ring:** `MemRing.qml` visualization with used/free/cache/swap breakdown
- **Reusable components:** Shared rows, meters, sparklines, action pills, and headers in `components/`
- **Formatting helpers:** `Model.js` for bytes, rates, temperatures, and process sort/filter logic
- **Settings:** `refreshSeconds` (1–10 s) controls collector sample interval

### Disk tab

- Physical drives from block metadata (partitions nested under parent drives)
- Transport glyphs for NVMe, SATA/HDD, and USB; amber accent for removable devices
- Removable external devices (USB sticks, SD cards) with device name, size, filesystem type, and mount point
- Mounted filesystem usage gauges; unmounted partitions listed and expandable
- Mount and unmount actions via `udisksctl` (custom mount path supported)
- SMART health and details per drive/mount via `pkexec smartctl`; install prompt when `smartmontools` is missing
- NVMe health percentage estimate where available

### GPU tab

- Intel and AMD metrics from sysfs (utilization, frequency, memory, temperature, power)
- NVIDIA metrics via `nvidia-smi` when the proprietary driver is present

### Process tab

- Sortable, filterable process table with keyboard cursor navigation
- Detail cards, terminate/kill confirmation, and pause/resume signal actions

### Navigation and integration

- Arrow keys, number-key tab jumps (`1`–`7`), process shortcuts, and Escape that unwinds detail → filter → panel
- IPC handler exposes `showTab(key)` for shell hotkeys (see table below)
- Temperature bands, fan rows, and clickable GPU/NVMe device links in the Temp tab

## Requirements

- Omarchy 4.0+ (Quattro)
- Quickshell with `qs.Ui` and `Quickshell.Io`
- Python 3 for the panel collector
- Optional: `smartmontools` for SMART disk health checks. The panel can offer installation through `pkexec pacman` when missing.

## Install

```bash
omarchy plugin add io.github.arslan.sysmon --enable
```

Or from a git URL once published:

```bash
omarchy plugin add https://github.com/<your-user>/io.github.arslan.sysmon --enable
```

## Remove

```bash
omarchy plugin remove io.github.arslan.sysmon
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

MIT — see [LICENSE](LICENSE).

## Credits

SysMon is inspired by [omarchy-vitals](https://github.com/Woogy7/omarchy-vitals) (MIT, Woogy7), which pioneered the bar-widget + panel collector pattern and btop-style tab layout for Omarchy.

On top of that baseline, this repo adds and changes:

- Overview-first panel navigation with drill-down sub-pages
- Dedicated Temp tab (core temps, fans, device links)
- Physical drive tree with removable/USB detection, mount/unmount, and SMART tooling
- Process tab with sort, filter, keyboard cursor, detail cards, and signal actions
- Lazy tab loading, reusable `tabs/` + `components/` architecture, and `MemRing.qml`
- Bar/panel sync, sparkline histories, GPU vendor queries (`nvidia-smi`), and keyboard/IPC hotkeys
