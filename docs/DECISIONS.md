# Decisions and verified behaviour

Facts established by running the thing, not by reading docs. Each one is load
bearing; if one turns out to be false later, the design above it changes.

## The replay buffer must rename its own argv[0]

`omarchy-capture-screenrecording` gates its **entire entry point** on
`pgrep -f "^gpu-screen-recorder"` and stops recording with
`pkill -SIGINT -f "^gpu-screen-recorder"`. An armed replay buffer running under
the default name therefore means the user's screenrecord keybinding **stops the
replay buffer instead of starting a recording**.

So the buffer is launched as:

```bash
setsid bash -c "exec -a omarchy-game-center-replay gpu-screen-recorder …"
```

Verified 2026-09-20 against gpu-screen-recorder 6.1.0 on Omarchy (kernel
7.2.5-3-omarchy): with the rename in place, `pgrep -f '^gpu-screen-recorder'`
finds nothing while the buffer runs, and capture still works — a save produced a
6.0 s, 3440x1440, 60 fps h264 mp4. `tests/run.sh` pins this as a regression
test, because the mitigation dies silently if Omarchy ever un-anchors that
pattern.

## Talk to gsr over its own socket, not through a CLI

`-ipc <socket>` speaks newline-delimited JSON, and the reply to `save-replay`
**carries the saved file path**:

```
→ {"id":1,"name":"save-replay","data":{"seconds":5}}
← {"id":1,"result":"ok","data":"…/Replay_2026-09-20_13-04-48.mp4"}
```

That removes the "watch the directory and guess which file appeared" race.
Quickshell ships `Socket` in `Quickshell.Io`, so the QML side talks to gsr
directly. `gsr-cli -ipc <sock> save-replay` is the fallback, and `SIGUSR1` the
last resort (whole buffer, no path returned).

A save requested before the ring buffer holds a keyframe fails cleanly with
`{"result":"error","data":"failed to save the replay"}` — the UI must treat an
early save as a normal outcome, not an error state.

## Socket path

`$XDG_RUNTIME_DIR/omarchy-game-center/gsr.sock` is 45 bytes here, well inside
the 108-byte `sun_path` limit. `omaclippr` hardcodes `/tmp` claiming the limit
forces it; that isn't true and `/tmp` is a shared namespace. The launcher still
asserts the length and falls back to `/tmp/omarchy-game-center-$UID/`.

## Never identify our own process by `comm`

`/proc/<pid>/comm` truncates at 15 characters, so `pgrep -x
omarchy-game-center-replay` matches nothing. Match on the full command line
(`pgrep -f "^omarchy-game-center-replay "`) — and in the plugin itself, use the
recorded pid + start-time file rather than pattern matching at all.

`SIGTERM` did not stop the recorder within 2 s in testing. Stop it the way the
stock script does, with `SIGINT` (which finalizes the file properly), then
escalate.

## Newly created QML needs a full shell restart

Editing a file the shell has already loaded hot-reloads fine. A **newly created**
plugin or QML file is served from a stale compilation until
`omarchy-restart-shell` — a fixed error keeps being reported at the old line and
column, which is misleading while developing. Restart before believing an error
that no longer matches the source.

## `gc` is a reserved property name in QML

`readonly property var gc: …` fails with `Illegal property name`. The service
handle on the panel is called `gameCenter`.

## Replay buffer memory is mostly fixed cost, not payload

Measured RSS of the armed buffer against its nominal payload
(`kbps x seconds / 8`):

| capture | payload | RSS |
|---|---|---|
| 2560x1440, 26.7 Mbps, 30 s | 100 MB | 285 MB |
| 2560x1440, 53.3 Mbps, 30 s | 200 MB | 379 MB |
| 3440x1440, 35.8 Mbps, 30 s | 134 MB | 433 MB |

The encoder's working set is a large cost that tracks capture resolution, not
buffer length, so a multiplier badly under-counts short buffers — 15 s at
1080p would be quoted at ~50 MB while actually costing several hundred. Both
the preflight and the panel's estimate use **payload + 400 MB**.

## The buffer defaults to 60 fps on a 144 Hz monitor

Matching the monitor's refresh rate doubles the bitrate, and therefore the
memory held for the entire session, plus the encoder load while you are trying
to play. Clips get watched back, not competed in. 60 is the default and
anything up to 240 can be asked for explicitly.

## Restarting the shell twice in quick succession leaves it dead

`omarchy-restart-shell` kills the running instance and starts a new one. Issue
a second restart while the first is still coming up and the new instance exits
with "An instance of this configuration is already running", after which the
original is killed anyway — leaving no shell and no bar. Wait for
`omarchy-shell shell ping` to answer `ok` before restarting again.

## sysfs spells driver names with hyphens, /proc/modules with underscores

The same driver is `xone-gip-gamepad` in `/sys/.../driver` and
`xone_gip_gamepad` in `/proc/modules`. `gc-pad-probe` normalises to
underscores before looking up capabilities.

This is not cosmetic. Keyed on the wrong spelling, every pad falls through to
the default capability set, and the panel then reports a perfectly good Xbox
controller as having no rumble, no battery and no light — which is exactly what
it did until a real controller was connected. Capability tables that fail
*closed* hide their own bugs, so the test suite now asserts that a connected pad
carries a full capability set.

## What an Xbox pad actually reports (measured, dongle connection)

```
driver      xone_gip_gamepad        (sysfs: xone-gip-gamepad)
connection  dongle
battery     level "Full", status "Discharging", percent null
led         /sys/class/leds/gip0.0:white:status
            max_brightness 50, brightness 20, mode present, writable false
caps        rumble true, triggerRumble false, batteryKind level,
            charging false, led true, deadzone false
```

`percent` is null and `status` never says Charging, exactly as the driver's
property list implies. Five segments is the honest rendering.

Rumble over evdev works with no root and no udev rule: `sizeof(ff_effect)` is
48 bytes on x86_64, `EVIOCSFF` is `0x40304580`, and a 70/40 effect for 600ms
returns in 0.68s.

## The Xbox button codes come from the driver, not from the header names

```
A 0x130    B 0x131    X 0x133    Y 0x134
```

`input-event-codes.h` aliases the letters to *positions* using a Nintendo-style
face layout — `BTN_X` is `BTN_NORTH`, `BTN_Y` is `BTN_WEST` — while an Xbox pad
has X in the west position and Y in the north one. Read the positional names,
reason about where the buttons physically sit, and X and Y come out swapped.
That is what the first version of the table did, and the live view lit the
wrong chip.

`xone` settles it by emitting the letter macros directly
(`driver/gamepad.c:406-409`, `input_report_key(dev, BTN_X, ...)`), so the letter
is what the driver means and the position is a red herring. `hid_xpadneo` does
the same.

Worth recording how this was *actually* pinned down, because the first two
attempts were not sound. Asking a person to press A, B, X, Y in order and
reading back the codes only works if they press in that order — the first
capture turned out to be random presses, and the inference drawn from it
("B and Y are crossed") was nonsense built on bad data. The second capture was
in order and gave the right answer, but it was still an answer that depended on
someone else's care. Reading the driver source is independent of all that, and
should have been the first move rather than the third. `tests/run.sh` asserts
the table so the question stays settled.

## Live input reads evdev directly instead of using SDL

SDL's gamepad database normalises pads nobody has heard of, which is real
value. It also means `python-pysdl3`, which is not installed by default — and
on this machine `python-evdev` was installed but built for an older Python than
the running 3.14, so it would not import either. A controller tab whose first
act is to ask for a package install is a tab nobody uses.

Reading evdev directly is about sixty lines of stdlib, exact for anything
following the kernel's gamepad convention, and needs no root: gamepad event
nodes are uaccess-tagged for the logged-in seat. The NDJSON protocol carries a
`backend` field in its hello line, so an SDL backend can be added later without
the panel changing.

The streamer's lifetime is the subscription: the panel starts it when the live
view opens and kills it when the tab closes. No idle process, no stdin
protocol, and a crash costs nothing but the picture until the next open.
