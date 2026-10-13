# linux-wallpaperengine on niri + Noctalia v5

Configuration guide. Everything below is verified against the source of the
revision we build (`Almamu/linux-wallpaperengine` @ `b016d7d`) and the niri
v26.04 / Noctalia v5 docs.

---

## TL;DR — the one thing that matters

On niri you **must** run with `--layer background`:

```bash
linux-wallpaperengine --layer background --fps 30 --silent <wallpaper-id>
```

and add a layer rule so niri puts it in the backdrop:

```kdl
// ~/.config/niri/config.kdl
layer-rule {
    match namespace="^linux-wallpaperengine$"
    place-within-backdrop true
}
```

Without `--layer background` the engine defaults to the **bottom** layer, which
on niri sits *above* the backdrop — so the wallpaper gets cloned into every
workspace thumbnail in the overview instead of staying behind everything.
`place-within-backdrop` **only applies to background-layer surfaces**, so the
two settings are a pair: neither works without the other.

---

## Why not just use Noctalia's own wallpaper

Noctalia v5 draws its wallpaper on a layer-shell surface named
`noctalia-wallpaper`, also on the `background` layer
(`src/shell/wallpaper/wallpaper.cpp`). It has no way to host a live
linux-wallpaperengine scene — it renders stills and GIFs.

So when you run linux-wallpaperengine on the same output you end up with **two
background-layer surfaces**. Layer-shell has no defined ordering between
surfaces on the same layer, so which one wins is effectively up to niri's
internal surface order — it's not something you can reliably predict or control
from config.

You have two options:

### Option A — let the engine own the wallpaper (recommended)

Give the engine the whole desktop and stop Noctalia from painting one:

- Set Noctalia's wallpaper to a solid colour so it costs nothing to render:
  ```
  noctalia msg wallpaper-set color:#000000
  ```
  (per output: `noctalia msg wallpaper-set DP-1 color:#000000`)

  The engine's surface is opaque (`wl_surface_set_opaque_region` covers the full
  surface in `WaylandOutputViewport.cpp`), so the compositor skips everything
  underneath — Noctalia's fill never actually gets composited. This is only
  about avoiding a second full-screen surface, not about pixels.

- **Trade-off:** Noctalia derives your shell colour scheme from the current
  wallpaper image. With a solid colour, the shell stays on whatever palette that
  colour produces. If you want the shell themed to the wallpaper, hand it a
  still — the engine can do that for you:

  ```bash
  linux-wallpaperengine --screenshot ~/Pictures/we-still.png --screenshot-delay 60 <id>
  noctalia msg wallpaper-set ~/Pictures/we-still.png
  ```

  `--screenshot-delay` counts **frames**, not seconds (default 5). At 30 fps,
  60 frames ≈ 2 s. Noctalia will paint that still on its own surface behind the
  engine's — harmless, and it keeps the palette pipeline fed.

### Option B — use the W Engine plugin

There's a Noctalia community plugin that drives linux-wallpaperengine for you:
`tadomika_ari/w-engine` (v1.4.0). It gives you a bar widget + panel, wallpaper
picking from the Workshop, per-wallpaper settings, cycling, and — relevant here
— it hands Noctalia a still of the wallpaper so shell colours keep working, and
restores the previous wallpaper when you hit Stop.

Install it from **Settings → Plugins** in Noctalia.

It emits exactly the same engine flags (scaling, clamp, **Wayland layer**, FPS,
volume, mute, automute, audio processing, particles, mouse, parallax, fullscreen
pause), so the `--layer background` advice above still applies — set it in the
plugin's per-wallpaper or global playback controls instead of on the command
line.

**Pick one or the other.** Don't run the engine by hand *and* via the plugin;
you'll get two engine processes fighting over the same layer.

---

## Recommended command line

```bash
linux-wallpaperengine \
    --layer background \
    --fps 30 \
    --silent \
    <wallpaper-id>
```

### On your hardware (AMD 6800H iGPU, no dGPU)

| Flag | Why |
| --- | --- |
| `--layer background` | required for niri (see above) |
| `--fps 30` | default is 30; drop to `--fps 15` or `24` on battery. This is the single biggest power lever. |
| `--silent` | no audio. Without it the engine decodes and mixes audio every frame even if you never hear it. |
| `--no-fullscreen-pause` | **don't use this** — you want the pause. Leave it off. |
| `--fullscreen-pause-only-active` | **recommended on niri.** niri is a scrollable tiling compositor, so it has "virtual" fullscreen windows that aren't really focused. Without this flag the engine pauses whenever *any* toplevel reports fullscreen, including ones on other workspaces. |
| `--fullscreen-pause-ignore-appid <val>` | repeatable; use for apps that report fullscreen but shouldn't stop the wallpaper (e.g. `--fullscreen-pause-ignore-appid mpv`). |
| `--disable-mouse` | saves a little CPU if you don't want parallax/mouse interaction. Note the engine sets its input region to click-through when mouse is disabled. |
| `--disable-particles` / `--disable-parallax` | per-wallpaper CPU savers when a scene is heavy. |

Do **not** reach for `--no-fullscreen-pause`: pausing when a fullscreen app is
up is exactly what you want for battery life, and on niri the
`--fullscreen-pause-only-active` flag makes that logic correct.

---

## Assets and Workshop content

The engine needs two things: Wallpaper Engine's `assets/` (shaders, materials,
models — payware) and the workshop item itself.

- Assets: either let it auto-detect a real Steam install, or point at a mirror:
  ```bash
  --assets-dir ~/.local/share/wallpaper-engine/assets
  ```
  Auto-detection looks up Steam's `wallpaper_engine/assets`; if that fails it
  falls back to `<dir-of-binary>/assets`. Since our package installs to
  `/opt/linux-wallpaperengine`, that fallback lands inside `/opt` — so if you
  don't own the game on Steam, **pass `--assets-dir` explicitly.**

- A wallpaper can be given as a workshop ID (`1845706469`) or a path
  (`~/backgrounds/1845706469/`). IDs are resolved through Steam's workshop
  directory, so a path is more reliable when Steam isn't installed.

---

## Multi-monitor

Per screen, with independent scaling:

```bash
linux-wallpaperengine \
    --layer background \
    --screen-root DP-1 --bg 1845706469 --scaling fill \
    --screen-root HDMI-A-1 --bg 2667198601 --scaling fit
```

One wallpaper stretched across several outputs (needs `xdg-output`, which niri
provides):

```bash
linux-wallpaperengine --layer background \
    --screen-span DP-1,DP-2 --bg 1845706469 --scaling fill
```

Get your connector names from `niri msg outputs`.

---

## Keeping it running

linux-wallpaperengine has no daemon mode — it's one process per invocation, and
it exits if it crashes. niri's recommended pattern is a user service tied to the
graphical session (same approach the niri docs use for swaybg):

`~/.config/systemd/user/linux-wallpaperengine.service`:

```ini
[Unit]
PartOf=graphical-session.target
After=graphical-session.target
Requisite=graphical-session.target

[Service]
ExecStart=/usr/bin/linux-wallpaperengine --layer background --fps 30 --silent 1845706469
Restart=on-failure

[Install]
WantedBy=graphical-session.target
```

```bash
systemctl --user daemon-reload
systemctl --user add-wants niri.service linux-wallpaperengine.service
```

`add-wants` creates the symlink under `~/.config/systemd/user/niri.service.wants/`,
so the service starts and stops with the niri session. To remove it later, delete
that symlink and run `systemctl --user daemon-reload`.

This only applies when niri runs as a session (started via `niri-session` from a
display manager). If you launch niri from a TTY directly, use niri's
`spawn-at-startup` instead.

If you go the plugin route, **don't** enable this — the plugin owns the process
lifecycle.

---

## Quick verification

```bash
# is the engine on the background layer?
niri msg layers | grep -i wallpaperengine

# what does niri call it (namespace)?
niri msg layers

# confirm the binary is the v3 build
readelf -n /opt/linux-wallpaperengine/linux-wallpaperengine | grep -i x86-64-v
```

`niri msg layers` is the ground truth for the namespace string used in the layer
rule. If your rule doesn't match, check the actual namespace there — the engine
sets it to `linux-wallpaperengine` (`WaylandOutputViewport.cpp`, the
`zwlr_layer_shell_v1_get_layer_surface` call).

---

## Gotchas

- **Overview shows the wallpaper duplicated** → you're on the `bottom` layer;
  add `--layer background` *and* the `place-within-backdrop` rule.
- **Black screen** → almost always a missing/wrong `--assets-dir`, or a second
  background-layer surface (Noctalia's) covering it.
- **Engine exits immediately** → check `--assets-dir` first; the fallback path
  is relative to the binary, which lives in `/opt`.
- **High GPU use on a scene wallpaper** → try `--fps 24`, then
  `--disable-particles`, then `--disable-parallax`. Scene wallpapers with heavy
  effect chains are the expensive ones; video wallpapers are cheap.
- **`--screenshot-delay` is frames, not seconds** — easy to get wrong.
