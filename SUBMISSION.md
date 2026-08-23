# Plugin Creation & Submission — Agent Guide

## Objective

Create and submit plugins to the Omarchy Plugin Competition by Monday Aug 24, 9am CEST.

## Plugin Submission Process

1. Create plugin in `~/.config/omarchy/plugins/<plugin-id>/`
2. Test locally (hot reload or `omarchy restart shell`)
3. Validate: `omarchy plugin validate <folder-name>`
4. Enable: `omarchy plugin enable <plugin-id>`
5. Submit to marketplace repo: `https://github.com/HANCORE-linux/omarchy-plugin-marketplace`

## Plugin Structure Required

```
plugin-id/
  manifest.json    # Required: metadata, entry points, settings
  BarWidget.qml    # Required: bar widget entry point
  Panel.qml        # Optional: detail panel
  README.md        # Required: description
  preview.png      # Required: screenshot
```

## manifest.json Schema

```json
{
  "schemaVersion": 1,
  "id": "io.github.<username>.<plugin-name>",
  "name": "Display Name",
  "version": "1.0.0",
  "author": "username",
  "license": "MIT",
  "description": "Short description",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" },
  "barWidget": {
    "displayName": "Name",
    "description": "Description",
    "category": "System",
    "allowMultiple": false,
    "defaultSection": "right",
    "defaults": {},
    "schema": []
  }
}
```

## Key APIs

### BarWidget (bar display)
- `moduleName: "plugin-id"` — must match manifest id
- `setting("key", default)` — read settings
- `bar` — parent bar reference
- `implicitWidth` / `implicitHeight` — widget size

### Panel (detail view)
- Extends `Panel` from `qs.Ui`
- `toggle()` — open/close
- `open()` / `close()`
- `anchorItem` — position relative to bar

### Data Reading
- `FileView { path: "/proc/stat" }` — read file, `.text()`, `.reload()`
- `Process { command: [...] }` — run command
- `Timer { interval; running; onTriggered }` — periodic updates

### Styling
- `Style.font.body` — 12px (standard)
- `Style.font.caption` — 10px (small)
- `Style.font.family` — shell font
- `Color.foreground` — text color (#cacccc)
- `Color.bar.background` — bar background
- `Style.bar.sizeHorizontal` — bar height

## Testing Checklist

- [ ] Plugin validates: `omarchy plugin validate <id>`
- [ ] Plugin enables: `omarchy plugin enable <id>`
- [ ] Plugin appears in bar
- [ ] Data updates in real-time
- [ ] Click behavior works
- [ ] Keyboard navigation works
- [ ] No QML errors in logs: `journalctl --user | grep sysmon`

## Common Issues

- **Plugin not showing:** Check manifest.json syntax, check QML errors in logs
- **QML compile error:** Shell caches QML — need `omarchy restart shell`
- **Property not updating:** Ensure property is `readonly` or has binding
- **Timer not firing:** Check `running: true` and `repeat: true`

## Git Workflow

```bash
cd ~/.config/omarchy/plugins/<plugin-id>
git init
git add .
git commit -m "feat: initial plugin"
git remote add origin <github-url>
git push -u origin main
```

## Marketplace Submission

1. Fork `https://github.com/HANCORE-linux/omarchy-plugin-marketplace`
2. Add plugin to the registry
3. Submit PR
