# Trackpad gestures for Omarchy

Swipe between workspaces with three or four fingers, macOS style: the windows
follow the fingers, and the workspace settles into place when they lift. A panel
in the bar picks the finger count, the direction and the travel.

三指或四指左右滑动切换工作区，画面跟手，跟 macOS 的 Spaces 一样。状态栏的
手形图标点开就是设置：手指数量、方向（自然 / 反向）、行程长短，还可以关掉
SUPER+1…0 的滑动过渡。

## What it does

- `hl.gesture({ fingers = N, direction = "horizontal", action = "workspace" })`
  registers the swipe; N comes from the panel.
- `hl.config({ gestures = { workspace_swipe_invert, workspace_swipe_distance } })`
  sets the direction and how far the fingers travel for a full switch.
- `hl.animation({ leaf = "workspaces", ... })` restores the short slide home
  that Omarchy switches off for instant `SUPER+1…0` jumps. Without it the
  gesture snaps the last half screen when the fingers lift. The panel's
  "顺滑收尾动画" toggle turns it off again.

Settings live in `~/.config/omarchy/trackpad-gestures.json`, the generated
Hyprland Lua in `~/.config/hypr/trackpad_gestures.lua`, and `hyprland.lua` gets
one `require("hypr.trackpad_gestures")` line so a config reload keeps the
gesture. `gestures.py` owns all three; the panel never writes files itself.

## Install

```bash
omarchy plugin validate ~/.config/omarchy/plugins/nox.trackpad-gestures
omarchy plugin enable nox.trackpad-gestures
```

`omarchy restart shell` after editing `Panel.qml`: the shell reloads a changed
plugin's manifest, but keeps the already compiled widget until it restarts.

## From the terminal

The same settings without the panel:

```bash
omarchy-trackpad-gestures state              # JSON
omarchy-trackpad-gestures set fingers 3
omarchy-trackpad-gestures set invert true    # fingers left = previous workspace
omarchy-trackpad-gestures set distance 400   # finger travel for a full switch
omarchy-trackpad-gestures set animation off  # back to instant SUPER+1…0
omarchy-trackpad-gestures set enabled false  # no gesture at all
omarchy-trackpad-gestures apply              # rewrite the Lua, reload if changed
```

`omarchy-trackpad-gestures` is a symlink to `gestures.py`; call the script by
path if the symlink is missing.

## Files

| Path | What |
|------|------|
| `manifest.json` | plugin id `nox.trackpad-gestures`, bar widget + service |
| `Panel.qml` | the bar icon and its settings panel |
| `Service.qml` | applies the settings when the shell starts (heals a fresh install or `omarchy refresh hyprland`) |
| `gestures.py` | settings store, Lua generator, `hyprctl reload` |

## Notes

- Direction is cosmetic on Hyprland's side: `workspace_swipe_invert` flips
  which way the neighbouring workspace moves in. Pick whichever feels natural.
- A three-finger swipe and a horizontal three-finger drag on a window both use
  three fingers. If drag-to-move-window (Niri style) is configured elsewhere, it
  will compete with the gesture; stick to four fingers then.
- The shell has to apply the settings once at login, so the gesture starts a
  couple of seconds after the shell does. After that it comes from Hyprland's
  own config, so `hyprctl reload` keeps it.
- The panel's labels are Chinese (it was written for a Chinese desktop). The
  generated Lua, the CLI and this README are English; translations welcome.

MIT licensed.
