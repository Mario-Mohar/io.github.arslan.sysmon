# SysMon — Competition Plan

## Goal

Win the Omarchy Plugin Competition. Deadline: Monday Aug 24, 9am CEST.

## Strategy

Make 2 plugins to maximize chances:

### Plugin 1: SysMon (current)
- 4 colored metrics in bar (CPU/MEM/TEMP/DISK)
- Unique angle: Color-coded states, at-a-glance monitoring
- Status: Bar widget working, panels broken
- Time to finish: 6-8 hours

### Plugin 2: New idea TBD
- Something unique not in existing 500+ plugins
- Time to build: 4-6 hours

## Vitals Analysis (competitor)

| Feature | Vitals | Our SysMon |
|---------|--------|------------|
| Bar display | 1 icon | 4 colored metrics |
| Panel tabs | CPU/MEM/DISK/NET/GPU/PROC | None yet |
| Data source | Python collector.py | FileView (QML native) |
| Color states | No | Yes |
| Keyboard nav | Yes | No |
| Sparklines | Yes | No |

Our advantage: Multi-metric bar + color states + no Python dependency

## What Judges Want

1. Idea — unique approach
2. Execution — polish, working features
3. Usefulness — daily utility
4. Code quality — clean, maintainable

## Plugin 2 Ideas

- Network monitor — live up/down speeds
- Process killer — quick kill from bar
- Backup monitor — last backup status
- Timer/stopwatch — productivity in bar
- Quick notes — sticky notes in bar

## Timeline

| Day | Task | Hours |
|-----|------|-------|
| Sat Aug 22 | Fix SysMon panels, wire clicks | 6 |
| Sun Aug 23 | Build Plugin 2, polish both | 6-8 |
| Mon Aug 24 9am CEST | SUBMIT | - |
