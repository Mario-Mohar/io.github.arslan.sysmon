# SysMon Plugin — Agent Guide

## Quick Start

Bar widget + tabbed popup panel: Overview, CPU, Temps, Memory, Disks, GPU, plus Network/Process sub-pages from Overview.
Bar shows four live glance metrics; the panel collects richer data via `collector.py` only while open.

## Files

| Path | Purpose |
|------|---------|
| `manifest.json` | Plugin metadata and settings schema (`refreshSeconds`) |
| `SysMon.qml` | Bar widget entry point with CPU, memory, temperature, and disk pills |
| `SysMonCore.qml` | Lightweight bar sampler using `/proc` and `/sys` |
| `Panel.qml` | Panel shell: collector process, IPC, keyboard navigation, history, SMART, mount/process actions, Overview UI, tab/sub-page loaders |
| `tabs/` | Current tab bodies: `CpuTab`, `TempTab`, `MemTab`, `DiskTab`, `NetTab`, `GpuTab`, `ProcTab` |
| `components/` | Reusable QML components: rows, meters, sparklines, pills, headers, confirm dialog helpers |
| `MemRing.qml` | Memory ring (QtQuick Shapes, `preferredRendererType: Shape.CurveRenderer`) |
| `Model.js` | Shared formatting and sorting helpers (`bytes`, `rate`, `temp`, process sorting/filtering, etc.) |
| `collector.py` | System snapshot collector, JSON on stdout; runs only while panel is open |
| `format.js` | Legacy bar formatting helpers still imported by `SysMon.qml` |
| `panels/` | Legacy 4-panel stubs kept for reference/compatibility, not the active architecture |
| `backup/` | Historical backup copy |

## Architecture

**Data flow:** `SysMon.qml` owns the bar pills and a lightweight `SysMonCore` sampler. When the popup opens, `Panel.qml` starts:

```bash
python3 collector.py --interval <refreshSeconds>
```

`collector.py` emits one JSON snapshot per line. `Panel.qml` parses each line into `root.snapshot`, updates histories, and feeds the selected tab.

**Tabs:** the active system uses an Overview-first layout:

1. Overview (default hub; inline in `Panel.qml`)
2. CPU
3. Temps
4. Memory
5. Disks
6. GPU (shown when a GPU is detected, or while waiting for first snapshot)

**Sub-pages** (from Overview, with ← Back): Network (`NetTab.qml`), Processes (`ProcTab.qml`).

Each dedicated tab body lives in `tabs/*.qml`. `Panel.qml` wraps each in a `Component` and instantiates only the active view through a `Loader`. Switching goes through `selectTab(index)`, `showSubPage(page)`, or `showTab(key)`.

**Keyboard navigation:**
- Left/Right or number keys `1`–`6`: switch main tabs
- Up/Down: scroll current tab, or move process cursor on Process sub-page
- Escape: close process detail, clear filter, go back from sub-page, or close panel
- Enter: activate process row detail
- Delete: request process terminate from cursor
- Process sub-page: `s`/`S` cycle sort, `r` reverses sort, `/` or `f` filters, `g`/`G` jump top/bottom

**IPC / hotkeys:** `Panel.qml` exposes `showTab(key)` through `IpcHandler`. Keys: `overview`, `cpu`, `temp`, `mem`, `disk`, `gpu`. Network and Processes open from Overview UI (sub-pages). Known shell bindings:
- `SUPER CTRL V`: CPU
- `SUPER CTRL B`: Memory
- `SUPER CTRL T`: Temps
- `SUPER CTRL D`: Disks
- `SUPER CTRL G`: GPU

**Dedup rules (deliberate):**
- Core temps grid + fan live in Temp tab only; CPU tab shows core count and CPU-focused metrics
- GPU/NVMe temps appear as clickable link rows in Temp's DEVICES block
- Process counts and process actions belong to the Process sub-page
- Memory ring + header + legend coexist by design (glance vs numbers)

## Disk Tab

- **DRIVES**: all physical block devices from `snapshot.blockdevs` (sysfs/lsblk backed, partitions excluded from the drive list), with transport glyphs: NVMe `\uF01A0`, HDD/SATA `\uF02CA`, USB `\uF08EB`; amber accent when removable
- Child partitions are rendered under their parent drive, including unmounted partitions discovered from block metadata
- Mounted filesystems get usage gauge cards and per-mount **SMART** actions
- Unmounted partitions can be mounted through the panel mount action when supported by the system
- Unmounted whole drives still get their own card and SMART access through `querySmartDev(name)`
- Index-based `querySmart(index)` and device-based `querySmartDev(name)` share `smartOut`/`smartState`, keyed by `smartIndex >= 0` or `smartDev !== ""`
- SMART runs through `pkexec smartctl`; if `smartmontools` is missing, the panel offers install via `pkexec pacman -S --needed --noconfirm smartmontools`
- Health % estimate = `100 - NVMe Percentage Used`; ATA-only drives do not get a fake score

## Color System

Theme-aware monochrome base (`Color.foreground` + alpha) with threshold accents via `stateColor(pct)`: <60% foreground, >=60% `#ffb800`, >=80% `#ff3333`. Fixed palette islands: MemRing uses blue/amber/purple; temperature bands use green to red.

## Reusable Components

Active reusable UI lives in `components/` and is imported by `Panel.qml` and tabs.

| Component file | Notes |
|-----------|-------|
| `SectionRowComponent.qml` | Label left / value right using safe Item + anchors idiom |
| `DriveHeadingComponent.qml` | Glyph + title left, dim metadata right |
| `StatCellComponent.qml` | Caption/value cell used in stat grids |
| `MeterComponent.qml` | Horizontal bar, `fillColor` prop for thresholds |
| `SparklineComponent.qml` | History graph for CPU, network, GPU, temp trends |
| `ActionPillComponent.qml` | Small bordered button for actions |
| `InfoPairComponent.qml`, `ShareRowComponent.qml`, `ColumnHeaderComponent.qml` | Shared rows/header helpers |

## QML Gotchas (learned the hard way)

- NEVER put `anchors.left/right/fill` on children of `Row`/`Column`. Use an `Item` wrapper with anchors, as the component files do.
- `ShapePath` is not an Item: no `visible`. Hide arcs with `strokeColor: "transparent"` instead.
- `Shape.rendererType` is read-only. Use `preferredRendererType`.
- `ShapePath.Flat/CapStyle` constants may be undefined in this Qt build. Omit capStyle unless verified.
- Icon glyphs need `font.family: Style.font.family` or `root.fontFamily`.
- Keep tab bodies in `tabs/` and shared controls in `components/`; avoid growing `Panel.qml` unless the state truly belongs to the panel shell.

## Settings

| Key | Default | Description |
|-----|---------|-------------|
| `refreshSeconds` | 1 | Panel collector sample interval in seconds, clamped 1-10 |

`SysMonCore` currently samples the bar every 2 seconds inside `SysMon.qml`.

## Hot Reload

- Edit files, then shell usually auto-detects
- If not: `omarchy-shell shell rescanPlugins`
- If broken: `omarchy restart shell`

## Debugging

```bash
# QML errors/warnings from the plugin
journalctl --user --since '10 min ago' | grep -iE 'qml|sysmon|io.github.arslan.sysmon'

# Test collector output directly
cd ~/.config/omarchy/plugins/io.github.arslan.sysmon
timeout 4 python3 collector.py --interval 1 | head -n 1 | python3 -m json.tool

# Lint current QML entry points, tabs, and components
qmllint Panel.qml SysMon.qml SysMonCore.qml MemRing.qml tabs/*.qml components/*.qml

# Quick brace-balance sanity check after scripted edits
python3 - <<'PY'
from pathlib import Path
for p in [Path('Panel.qml'), *Path('tabs').glob('*.qml'), *Path('components').glob('*.qml')]:
    q = p.read_text()
    print(p, q.count('{') - q.count('}'))
PY
```
