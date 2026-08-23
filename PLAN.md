# SysMon Plugin — Current Plan

## Product shape

SysMon is a polished Omarchy bar widget and dashboard:

- **Bar:** four compact live pills for CPU, memory, temperature, and disk usage.
- **Panel:** Overview hub plus CPU, Temps, Memory, Disks, and GPU tabs; Network and Process as Overview sub-pages.
- **Collector:** `collector.py` streams richer snapshots only while the panel is open.
- **Actions:** SMART checks, smartmontools install prompt, mount/unmount, and process signal controls.

The old per-resource files under `panels/` are legacy only. The active implementation uses `Panel.qml`, `tabs/`, and `components/`.

## Current file map

```text
io.github.arslan.sysmon/
├── manifest.json              # Plugin metadata and refreshSeconds setting
├── SysMon.qml                 # Bar widget with four metric pills and panel wiring
├── SysMonCore.qml             # Lightweight bar sampler from /proc and /sys
├── Panel.qml                  # Panel shell, collector process, IPC, histories, actions, tab loaders
├── collector.py               # JSON snapshot collector used only while panel is open
├── Model.js                   # Formatting, rates, uptime, sorting/filtering helpers
├── MemRing.qml                # Memory ring using QtQuick Shapes
├── format.js                  # Legacy bar formatting helpers still imported by SysMon.qml
├── tabs/
│   ├── CpuTab.qml
│   ├── TempTab.qml
│   ├── MemTab.qml
│   ├── DiskTab.qml
│   ├── NetTab.qml
│   ├── GpuTab.qml
│   └── ProcTab.qml
├── components/
│   ├── ActionPillComponent.qml
│   ├── ColumnHeaderComponent.qml
│   ├── DriveHeadingComponent.qml
│   ├── InfoPairComponent.qml
│   ├── MeterComponent.qml
│   ├── SectionRowComponent.qml
│   ├── ShareRowComponent.qml
│   ├── SparklineComponent.qml
│   └── StatCellComponent.qml
├── panels/                    # Legacy reference stubs, not active
└── backup/                    # Historical copy
```

## Data flow

```text
SysMon.qml
  ├─ SysMonCore samples bar stats every 2s
  └─ loads Panel.qml

Panel.qml, while open
  ├─ starts: python3 collector.py --interval <refreshSeconds>
  ├─ reads one JSON snapshot per stdout line
  ├─ stores root.snapshot and history arrays
  ├─ provides actions for SMART, mount, process signals, filtering, sorting
  └─ instantiates only the selected tab through Loader
```

This keeps the bar cheap and avoids running Python when the panel is closed.

## Dashboard views

| View | Purpose | Notes |
|---|---|---|
| Overview | System health hub, resource glance cards, top processes | Default tab; inline in `Panel.qml` |
| CPU | CPU usage, cores, load/frequency, history | CPU-focused only; core temp grid stays in Temps |
| Temps | CPU/core/device temps, thermal bands, fans | GPU/NVMe device rows link to GPU/Disks |
| Memory | Used/free/cache/swap breakdown and ring | `MemRing.qml` is intentionally a visual focal point |
| Disks | Physical drives, partitions, mounted filesystems, SMART, mount/unmount | Uses `snapshot.blockdevs` plus mounted filesystem data |
| GPU | GPU activity, memory/temp where exposed by system tools | Tab appears when GPU detected or before first snapshot |
| Network | Interfaces, RX/TX rates, history, counters | Sub-page from Overview; uses `NetTab.qml` |
| Processes | Sortable/filterable process table and signal actions | Sub-page from Overview; uses `ProcTab.qml` |

## Disk plan and behavior

- Show all physical block devices in the **DRIVES** section.
- Exclude partitions from the top-level drive list, then render children underneath their parent drive.
- Include unmounted partitions discovered from block metadata, not only `/proc/mounts`.
- Render mounted filesystems as usage gauge cards.
- Provide per-drive and per-mount SMART actions through `querySmartDev(name)` / `querySmart(index)`.
- Use `pkexec smartctl` for SMART details and offer `pkexec pacman -S --needed --noconfirm smartmontools` when missing.
- Provide a mount action for supported unmounted partitions.
- Estimate health percentage only for NVMe devices via `100 - Percentage Used`; do not invent fake ATA health scores.

## Keyboard and IPC plan

Panel-level navigation:

- Left/Right or `1`–`6`: switch main tabs (Overview, CPU, Temps, Memory, Disks, GPU).
- Up/Down: scroll normal tabs or move Process cursor on Process sub-page.
- Enter: activate process cursor/detail.
- Delete: request terminate for highlighted process.
- Escape: close process detail, clear filter, go back from sub-page, or close panel.

Process sub-page shortcuts:

- `s` / `S`: cycle sort column.
- `r`: reverse sort.
- `/` or `f`: focus filter.
- `g` / `G`: jump top/bottom.

IPC entry point:

```bash
omarchy-shell io.github.arslan.sysmon showTab overview
omarchy-shell io.github.arslan.sysmon showTab cpu
omarchy-shell io.github.arslan.sysmon showTab temp
omarchy-shell io.github.arslan.sysmon showTab mem
omarchy-shell io.github.arslan.sysmon showTab disk
omarchy-shell io.github.arslan.sysmon showTab gpu
```

Network and Processes are sub-pages — open from Overview in the panel UI.

Known hotkey mapping:

| Hotkey | Tab |
|---|---|
| `SUPER CTRL V` | CPU |
| `SUPER CTRL T` | Temps |
| `SUPER CTRL B` | Memory |
| `SUPER CTRL D` | Disks |
| `SUPER CTRL G` | GPU |

## Settings

| Setting | Default | Description |
|---|---:|---|
| `refreshSeconds` | 1 | Panel collector sample interval, clamped from 1 to 10 seconds |

The bar sampler interval is currently fixed in `SysMon.qml` / `SysMonCore.qml` at 2 seconds.

## Validation checklist

```bash
cd ~/.config/omarchy/plugins/io.github.arslan.sysmon

# Collector emits valid JSON
timeout 4 python3 collector.py --interval 1 | head -n 1 | python3 -m json.tool

# QML lint for active entry points, tabs, and components
qmllint Panel.qml SysMon.qml SysMonCore.qml MemRing.qml tabs/*.qml components/*.qml

# Quick brace-balance sanity check
python3 - <<'PY'
from pathlib import Path
for p in [Path('Panel.qml'), *Path('SysMon.qml'), Path('SysMonCore.qml'), Path('MemRing.qml'), *Path('tabs').glob('*.qml'), *Path('components').glob('*.qml')]:
    q = p.read_text()
    print(p, q.count('{') - q.count('}'))
PY
```

## Near-term cleanup

- Keep `Panel.qml` focused on shell state and process/action plumbing.
- Move tab body UI into `tabs/` and repeated controls into `components/`.
- Treat `panels/` and `backup/` as historical reference only.
- Keep README, AGENTS, PLAN, and competition notes in sync with any architecture changes.
