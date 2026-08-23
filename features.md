# SysMon Plugin Roadmap

Planned and in-progress work. Everything already shipped lives in [README.md](README.md).

## In progress

- **USB safe eject** — unmount works via `udisksctl`; still needs power-off so removable media can be physically removed without corruption.
- **GPU vendor metrics** — NVIDIA via `nvidia-smi` works; AMD ROCm (`rocm-smi`) parsing still missing.

## Planned

- **Configurable bar layout** — choose which bar pills appear and in what order.
- **Customizable panel** — pick which metrics show in each tab, their order, and per-metric thresholds.
- **Settings** — configure the plugin's behavior and appearance.
- **Threshold alerts** — desktop notifications when CPU, memory, disk, or temperature crosses user-defined limits.
- **USB ISO flashing** — write a bootable image to removable media from the Disk tab (with confirmation and progress).
