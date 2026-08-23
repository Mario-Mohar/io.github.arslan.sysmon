# SysMon — Competition Notes

## Goal

Submit the strongest possible Omarchy Plugin Competition entry before the final 9am CEST deadline.

Primary entry: **SysMon**, a polished bar widget plus Overview-first system dashboard.

## Current status

The current build has:

- Four live bar metrics: CPU, memory, temperature, disk (transparent pill backgrounds).
- Overview hub with system health glance, top processes, and drill-down sub-pages.
- Main tabs: Overview, CPU, Temps, Memory, Disks, GPU.
- Network and Process sub-pages from Overview.
- Keyboard navigation across tabs and within the Process sub-page.
- Sparklines/history for live trends.
- Python collector that runs only while the panel is open.
- SMART disk health/details with install prompt for `smartmontools`.
- Physical drives plus mounted filesystems and unmounted partitions.
- Mount and unmount actions for supported partitions.
- Process sorting, filtering, detail cards, and signal actions with confirmation for destructive operations.
- Reusable `tabs/` and `components/` architecture.
- Screenshots in `screenshots/`; marketplace preview at `preview.png`.
- LICENSE, install/remove docs, and `omarchy plugin validate .` passing.

## Positioning

SysMon should be presented as a daily-driver system monitor for Omarchy:

> Four calm at-a-glance metrics in the bar, one keyboard-friendly dashboard for everything else.

Key differentiators:

1. **Better glance value:** The bar communicates four useful system states without opening a panel.
2. **Focused depth:** Overview at a glance; dedicated tabs for CPU, Temps, Memory, Disks, GPU; Network and Processes as sub-pages.
3. **Keyboard-first polish:** Arrow keys, number-key tab jumps, process cursor, sort/filter shortcuts, and safe Escape behavior.
4. **Practical disk tooling:** Physical drives, unmounted partitions, mount action, SMART checks, and NVMe health percentage.
5. **Resource-conscious design:** Heavy collection only runs while the panel is open; hidden tabs are not instantiated.
6. **Integrated process management:** Process details and signals live in the same dashboard, with confirmation for terminate/kill.

## Competitor comparison

| Feature | Typical vitals-style plugin | SysMon |
|---|---|---|
| Bar display | Often one icon or compact status | Four metric pills: CPU, Mem, Temp, Disk |
| Dashboard coverage | CPU/Mem/Disk/Net/GPU/Proc varies by plugin | Overview hub + CPU, Temps, Memory, Disks, GPU + Net/Proc sub-pages |
| Data collection | Background or panel collector | Lightweight bar sampler plus on-demand panel collector |
| Keyboard navigation | Often partial | Full tab nav plus Process shortcuts |
| Sparklines/history | Often available | CPU, Temp, Net, GPU histories |
| Disk UX | Mounted filesystems | Physical drives, child partitions, unmounted partition display, SMART, mount actions |
| Process UX | Sometimes read-only | Sort/filter/detail/signals with confirmation |
| Color language | Usually generic | Theme-aware monochrome with amber/red thresholds and focused palette islands |

## Submission checklist

- [x] README accurately describes tabs, sub-pages, hotkeys, collector, SMART, mount, and process actions.
- [x] `manifest.json` metadata is current and versioned.
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

- [x] Capture screenshots showing bar pills, Overview, Disk/SMART, and Process sub-page.
- [x] Validate plugin with Omarchy tooling.
- [ ] Public GitHub repo pushed and marketplace form submitted.
- [ ] Tag final competition-ready version.

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
