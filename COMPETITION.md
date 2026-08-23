# SysMon — Competition Notes

## Goal

Submit the strongest possible Omarchy Plugin Competition entry before the final 9am CEST deadline.

Primary entry: **SysMon**, a polished bar widget plus 7-tab system dashboard.

## Current status

SysMon is no longer a broken 4-panel prototype. The current build has:

- Four live bar metrics: CPU, memory, temperature, disk.
- A working 7-tab dashboard: CPU, Temp, Mem, Disk, Net, GPU, Process.
- Keyboard navigation across tabs and within the Process tab.
- Sparklines/history for live trends.
- Python collector that runs only while the panel is open.
- SMART disk health/details with install prompt for `smartmontools`.
- Physical drives plus mounted filesystems and unmounted partitions.
- Mount action for supported unmounted partitions.
- Process sorting, filtering, detail cards, and signal actions with confirmation for destructive operations.
- Reusable `tabs/` and `components/` architecture instead of the old monolithic panel/panel-stub plan.

## Positioning

SysMon should be presented as a daily-driver system monitor for Omarchy:

> Four calm at-a-glance metrics in the bar, one keyboard-friendly dashboard for everything else.

Key differentiators:

1. **Better glance value:** The bar communicates four useful system states without opening a panel.
2. **Focused depth:** The popup opens directly to CPU, Memory, Temp, Disk, Network, GPU, or Process.
3. **Keyboard-first polish:** Arrow keys, number-key tab jumps, process cursor, sort/filter shortcuts, and safe Escape behavior.
4. **Practical disk tooling:** Physical drives, unmounted partitions, mount action, SMART checks, and NVMe health percentage.
5. **Resource-conscious design:** Heavy collection only runs while the panel is open; hidden tabs are not instantiated.
6. **Integrated process management:** Process details and signals live in the same dashboard, with confirmation for terminate/kill.

## Competitor comparison

| Feature | Typical vitals-style plugin | SysMon |
|---|---|---|
| Bar display | Often one icon or compact status | Four metric pills: CPU, Mem, Temp, Disk |
| Dashboard coverage | CPU/Mem/Disk/Net/GPU/Proc varies by plugin | CPU, Temp, Mem, Disk, Net, GPU, Process |
| Data collection | Background or panel collector | Lightweight bar sampler plus on-demand panel collector |
| Keyboard navigation | Often partial | Full tab nav plus Process shortcuts |
| Sparklines/history | Often available | CPU, Temp, Net, GPU histories |
| Disk UX | Mounted filesystems | Physical drives, child partitions, unmounted partition display, SMART, mount actions |
| Process UX | Sometimes read-only | Sort/filter/detail/signals with confirmation |
| Color language | Usually generic | Theme-aware monochrome with amber/red thresholds and focused palette islands |

## Submission checklist

- [ ] README accurately describes 7 tabs, hotkeys, collector, SMART, mount, and process actions.
- [ ] `manifest.json` metadata is current and versioned.
- [ ] Run collector smoke test:

  ```bash
  timeout 4 python3 collector.py --interval 1 | head -n 1 | python3 -m json.tool
  ```

- [ ] Run QML lint if available:

  ```bash
  qmllint Panel.qml SysMon.qml SysMonCore.qml MemRing.qml tabs/*.qml components/*.qml
  ```

- [ ] Check recent QML logs:

  ```bash
  journalctl --user --since '10 min ago' | grep -iE 'qml|sysmon|io.github.arslan.sysmon'
  ```

- [ ] Capture screenshots or GIFs showing:
  - bar pills,
  - full 7-tab dashboard,
  - Disk tab with drives/partitions/SMART,
  - Process tab with filter/sort/detail actions,
  - keyboard tab switching if using video.
- [ ] Validate plugin with Omarchy tooling if available.
- [ ] Tag or commit final competition-ready version.

## Plugin 2

Do not split focus unless SysMon is fully submitted. If there is extra time, a second plugin should be tiny, visually distinct, and submission-ready in under two hours.

Possible small ideas:

- **Backup status pill:** Shows latest backup age and warning color.
- **Timer/stopwatch pill:** Simple productivity timer with panel controls.
- **Quick notes pill:** Scratchpad popup with local text storage.

Recommendation: prioritize SysMon polish and submission assets over Plugin 2.

## Final polish priorities

1. Fix any QML errors from journal logs.
2. Ensure `collector.py` never breaks panel parsing when an optional system command fails.
3. Verify Disk tab behavior with mounted and unmounted partitions.
4. Verify Process tab actions do not allow accidental kill without confirmation.
5. Prepare screenshots/GIFs and a concise marketplace description.
