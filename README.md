# Game Center

The pre-game ritual in one Omarchy panel: session toggles, controllers and
instant replay, instead of six separate bar widgets that don't know about each
other.

> **Status: v0.2.0.** All three tabs work. Built and verified against a real
> Xbox One S on the `xone` driver, an Xbox Wireless Adapter, and
> gpu-screen-recorder 6.1.

## Install

```bash
omarchy plugin add https://github.com/Dielerorn/omarchy-game-center.git --enable
```

## What it does

**Session** — one switch for the things you flip before playing: keep awake, do
not disturb, night light, power profile. Game Center only ever changes what it
owns: anything you'd already turned on yourself is left exactly as it was, and
restored state is never guessed. If another tool already holds the stay-awake
marker, the panel says so instead of fighting it.

**Pads** — connected controllers with battery, connection type and driver, a
rumble test, and a live input view. Controls that can't work on your hardware
are absent rather than dead: an Xbox pad on `xone` reports battery in five
levels and has no charging state, so that's what's drawn — no invented
percentages. There is no deadzone slider, because Linux Xbox pads have no
deadzone control; that lives in Steam Input or the game.

**Clips** — an instant-replay buffer, a save-the-last-N-seconds button, and your
recent clips. Saving is bound to a key, not to having the panel open:

```
omarchy-shell -q dielerorn.gamecenter saveClip
```

## Roadmap

All five milestones are in:

| | |
|---|---|
| **M0** | Scaffold, service, panel, IPC |
| **M1** | Session toggles and the ownership model |
| **M2** | Replay arm / disarm / save |
| **M3** | Clip list and thumbnails |
| **M4** | Controller inventory, battery, rumble |
| **M5** | Live input view, guide LED, dongle pairing |

Next, roughly in order of usefulness: a game library with per-game profiles,
a drawn controller silhouette to replace the chip grid, and routing recording
and replay through one recorder instance rather than two.

## Requirements

Omarchy with the Quickshell shell, and `gpu-screen-recorder` for replay — which
Omarchy already ships. Nothing else: the controller tab reads evdev and sysfs
directly, so live input, battery and rumble need no Python packages and no
root. `ffmpeg` is used for clip thumbnails if present and degrades to a glyph if
not.

Two Xbox controls — the guide-button light and pairing from the panel — are
root-owned and stay hidden unless you install the optional udev rule; the panel
offers to walk you through it. See `docs/UDEV.md`.

## Development

The repository *is* the plugin directory — `omarchy plugin validate` rejects
symlinks, so there's no second copy to keep in sync.

```bash
git clone https://github.com/Dielerorn/omarchy-game-center.git \
  ~/.config/omarchy/plugins/dielerorn.gamecenter
omarchy plugin validate ~/.config/omarchy/plugins/dielerorn.gamecenter
journalctl --user -t omarchy-shell -f    # QML errors land here
```

Saving a file hot-reloads it. A *newly created* file needs
`omarchy-restart-shell` — until then the shell reports errors from a stale
compile, at line numbers that no longer exist. `docs/DECISIONS.md` records that
and the other behaviour this plugin is built on.

## Licence

MIT. See `THIRD_PARTY_NOTICES.md` for design lineage — the community plugins
this one learned from, none of which it depends on at runtime.
