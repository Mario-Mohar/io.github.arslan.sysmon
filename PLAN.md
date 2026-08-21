# SysMon Plugin — Design Plan

## What it does

**Bar:** Four compact text segments
```
󰍛 2.4GHz (15%) | 󰑭 45% | 󰔏 65° | 󰋊 45%
```

**Click each → opens its own panel:**
- Click `󰍛` → CPU panel (cores, frequency, load, sparkline)
- Click `󰑭` → Memory panel (used/free/cached/swap)
- Click `󰔏` → Temperature panel (sensors, thermal zones)
- Click `󰋊` → Disk panel (partitions, IO, usage)

## Files

```
io.github.arslan.sysmon/
├── manifest.json              # Plugin metadata
├── SysMon.qml                 # Bar widget (4 compact segments)
├── SysMonCore.qml             # Shared sampler (reads /proc, /sys via FileView)
├── panels/
│   ├── CpuPanel.qml           # CPU detail panel
│   ├── MemPanel.qml           # Memory detail panel
│   ├── TempPanel.qml          # Temperature detail panel
│   └── DiskPanel.qml          # Disk detail panel
└── format.js                  # Formatting helpers
```

## Design patterns

| Source | What we copy |
|---|---|
| **omarchy-sysmon** | `SysMonCore.qml` — FileView-based /proc reading (CPU, mem, network) |
| **omarchy-vitals** | `Model.js` → `format.js` — bytes(), percent(), temp(), mhz(), rate() |
| **omarchy-vitals** | Panel layout — PanelKeyCatcher, Sparkline, Meter, InfoPair, SectionRow |
| **Omarchy shell** | Style.font, Color, Style.space(), BarWidget, Panel, WidgetButton |

## Settings (in manifest.json)

| Setting | Default | Description |
|---|---|---|
| `interval` | 2 | Sample interval (seconds) |
| `showCpu` | true | Show CPU segment |
| `showMemory` | true | Show memory segment |
| `showTemp` | true | Show temperature segment |
| `showDisk` | true | Show disk segment |
| `showIcons` | true | Show Nerd Font icons |
| `onClick` | `omarchy-launch-or-focus-tui btop` | Default click command |

## Install

```bash
omarchy plugin add io.github.arslan.sysmon --enable
```
