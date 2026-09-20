#!/bin/bash
#
# Game Center tests. Run from anywhere:  tests/run.sh
#
# These are not unit tests of pure functions — the things most likely to break
# this plugin are assumptions about *other* software, so that is what gets
# pinned. Anything requiring a live Wayland session is skipped when there
# isn't one, so this can also run in CI.
#
set -uo pipefail

PLUGIN_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
PASS=0; FAIL=0; SKIP=0

ok()   { printf '  \033[32mpass\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf '  \033[33mskip\033[0m  %s (%s)\n' "$1" "$2"; SKIP=$((SKIP+1)); }

echo "Game Center tests"
echo

# ---------------------------------------------------------------- static

echo "helpers"
# bin/ holds both bash and python; check each with its own parser rather than
# running bash -n over a python file and calling the syntax error a failure.
for f in "$PLUGIN_DIR"/bin/*; do
  name="$(basename "$f")"
  [[ -x $f ]] || bad "$name is executable"
  case "$(head -1 "$f")" in
    *python*)
      if python3 -c "import ast,sys;ast.parse(open(sys.argv[1]).read())" "$f" 2>/dev/null
      then ok "$name parses (python)"; else bad "$name parses (python)"; fi
      ;;
    *)
      if bash -n "$f" 2>/dev/null; then ok "$name parses (bash)"; else bad "$name parses (bash)"; fi
      ;;
  esac
done

if command -v shellcheck >/dev/null; then
  for f in "$PLUGIN_DIR"/bin/*; do
    case "$(head -1 "$f")" in *python*) continue ;; esac
    name="$(basename "$f")"
    if shellcheck -S warning "$f" >/dev/null 2>&1; then ok "$name shellcheck"
    else bad "$name shellcheck ($(shellcheck -S warning -f gcc "$f" 2>/dev/null | head -1))"; fi
  done
else
  skip "shellcheck" "not installed"
fi

echo
echo "qml"
if command -v qmllint >/dev/null; then
  while IFS= read -r f; do
    name="${f#"$PLUGIN_DIR"/}"
    # qmllint cannot resolve the shell's qs.* modules, so only syntax errors
    # (which it reports with a line:col) count as failures here.
    out="$(qmllint "$f" 2>&1 | grep -E 'Syntax error|Illegal|Expected token' | head -1)"
    if [[ -z $out ]]; then ok "$name"; else bad "$name: $out"; fi
  done < <(find "$PLUGIN_DIR" -name '*.qml' -not -path '*/.git/*')
else
  skip "qmllint" "not installed"
fi

echo
echo "manifest"
if command -v omarchy-plugin-validate >/dev/null || command -v omarchy >/dev/null; then
  if omarchy plugin validate "$PLUGIN_DIR" >/dev/null 2>&1; then ok "validates"
  else bad "validates ($(omarchy plugin validate "$PLUGIN_DIR" 2>&1 | head -1))"; fi
else
  skip "manifest validation" "omarchy not installed"
fi
if jq -e '.barWidget.schema | length > 0' "$PLUGIN_DIR/manifest.json" >/dev/null 2>&1; then
  ok "settings schema present"
else
  bad "settings schema present"
fi

# ---------------------------------------------------------------- live

echo
echo "replay buffer (live)"
if [[ -z ${WAYLAND_DISPLAY:-} ]] || ! command -v gpu-screen-recorder >/dev/null; then
  skip "replay buffer" "needs a Wayland session with gpu-screen-recorder"
else
  # THE regression test.
  #
  # omarchy-capture-screenrecording gates its entry point on
  # `pgrep -f "^gpu-screen-recorder"` and stops with pkill -SIGINT on the same
  # pattern. Our buffer runs under a different argv[0] so the two do not see
  # each other. If Omarchy ever un-anchors that pattern, or our rename stops
  # working, this fails — which is the whole point. Silence here would mean the
  # user's screenrecord key quietly kills their replay buffer.
  if "$PLUGIN_DIR/bin/gc-replay" arm --seconds 5 --quality low >/dev/null 2>&1; then
    if pgrep -f '^gpu-screen-recorder' >/dev/null; then
      bad "armed buffer is invisible to Omarchy's recording detector"
    else
      ok "armed buffer is invisible to Omarchy's recording detector"
    fi

    pidfile="${XDG_RUNTIME_DIR}/omarchy-game-center/replay.pid"
    read -r pid _ <"$pidfile" 2>/dev/null
    if [[ -n ${pid:-} && -d /proc/$pid ]]; then ok "buffer process is tracked by pid file"
    else bad "buffer process is tracked by pid file"; fi

    # comm is truncated to 15 chars by the kernel, so anything matching our
    # renamed process by name must use the full command line.
    if [[ "$(cat /proc/$pid/comm 2>/dev/null)" != "omarchy-game-center-replay" ]]; then
      ok "process name is truncated in comm (pid file is the only safe identity)"
    else
      skip "comm truncation" "kernel no longer truncates comm"
    fi

    "$PLUGIN_DIR/bin/gc-replay" disarm >/dev/null 2>&1
    if ! pgrep -f '^omarchy-game-center-replay ' >/dev/null; then ok "disarm stops the buffer"
    else bad "disarm stops the buffer"; fi
  else
    bad "buffer arms"
  fi
fi

echo
echo "session ownership (live)"
if ! command -v omarchy-toggle-idle >/dev/null; then
  skip "session ownership" "omarchy not installed"
else
  marker="$HOME/.local/state/omarchy/indicators/stay-awake"
  probe="$("$PLUGIN_DIR/bin/gc-session" probe 2>/dev/null)"
  state="$(jq -r '.stayAwake.state' <<<"$probe" 2>/dev/null)"

  case "$state" in
    free|manual|foreign|ours) ok "stay-awake state is one of free/manual/foreign/ours ($state)" ;;
    *) bad "stay-awake state is recognisable (got '$state')" ;;
  esac

  # The three-state rule: a marker with an empty body is the user's own doing
  # and must never be claimed.
  if [[ -f $marker && ! -s $marker ]]; then
    if [[ $state == "manual" ]]; then ok "empty marker reads as the user's manual setting"
    else bad "empty marker reads as manual (got '$state')"; fi
  else
    skip "empty marker case" "marker is not currently empty"
  fi

  if jq -e '.power.available | type == "array"' <<<"$probe" >/dev/null 2>&1; then
    ok "power profiles are enumerated"
  else
    bad "power profiles are enumerated"
  fi
fi

echo
echo "controllers"
probe="$("$PLUGIN_DIR/bin/gc-pad-probe" 2>/dev/null)"
if jq -e '.pads | type == "array"' <<<"$probe" >/dev/null 2>&1; then
  ok "pad probe returns an inventory ($(jq '.pads | length' <<<"$probe") connected)"
else
  bad "pad probe returns an inventory"
fi

# Every pad must carry a full capability set, because the UI binds each control
# to one of these and an undefined capability renders as a control that lies.
if jq -e '[.pads[].caps | has("rumble") and has("batteryKind") and has("led")] | all' \
     <<<"$probe" >/dev/null 2>&1; then
  ok "every pad carries a full capability set"
else
  bad "every pad carries a full capability set"
fi

# The MSI motherboard exposes "MS MSI Gaming Controller" for its RGB lighting.
# It is not a gamepad and must never be offered a rumble test.
if jq -e '[.pads[].name | test("MSI"; "i")] | any' <<<"$probe" >/dev/null 2>&1; then
  bad "non-gamepad devices are excluded (MSI lighting matched)"
else
  ok "non-gamepad devices are excluded"
fi

if jq -e '.dongles | type == "array"' <<<"$probe" >/dev/null 2>&1; then
  ok "dongles enumerated ($(jq '.dongles | length' <<<"$probe") found)"
else
  bad "dongles enumerated"
fi

# The button map comes from xone's driver/gamepad.c, which emits the letter
# macros directly: BTN_A/BTN_B/BTN_X/BTN_Y = 0x130/0x131/0x133/0x134.
#
# input-event-codes.h aliases those letters to *positions* in a Nintendo-style
# layout (BTN_X is BTN_NORTH), and an Xbox pad has X in the west position — so
# reasoning from where the buttons physically sit transposes X and Y, which is
# exactly the bug this pins.
if python3 - "$PLUGIN_DIR/bin/gc-pads" <<'PYEOF' >/dev/null 2>&1
import sys, re
src = open(sys.argv[1]).read()
block = re.search(r"BUTTONS = \{(.*?)\}", src, re.S).group(1)
want = {"0x130": "a", "0x131": "b", "0x133": "x", "0x134": "y"}
got = dict(re.findall(r"(0x1[0-9a-f]{2}):\s*\"(\w+)\"", block))
sys.exit(0 if all(got.get(k) == v for k, v in want.items()) else 1)
PYEOF
then ok "button map matches the xone driver's BTN_A/B/X/Y"
else bad "button map matches the xone driver (X/Y likely transposed)"; fi

# ff_effect is 48 bytes on x86_64 and the ioctl number is derived from it, so a
# wrong struct means rumble silently does nothing on some machines.
size="$(python3 -c "
import ctypes, sys
sys.argv = ['x']
src = open('$PLUGIN_DIR/bin/gc-rumble').read().split('def clamp_percent')[0]
exec(src)
print(ctypes.sizeof(FFEffect))
" 2>/dev/null)"
if [[ "$size" == "48" ]]; then ok "ff_effect struct is 48 bytes"
else bad "ff_effect struct is 48 bytes (got '$size')"; fi

echo
echo "overlay"
stats="$("$PLUGIN_DIR/bin/gc-stats" --interval 0.3 2>/dev/null | head -2 | tail -1)"
if jq -e '.t == "stats"' <<<"$stats" >/dev/null 2>&1; then
  ok "stats helper emits a sample"
else
  bad "stats helper emits a sample"
fi

# A metric that cannot be read must be absent, not zero — the overlay leaves
# the row out rather than confidently showing 0%.
if jq -e 'has("cpu") and (.cpu.percent | type == "number")' <<<"$stats" >/dev/null 2>&1; then
  ok "cpu load is a number"
else
  bad "cpu load is a number"
fi
if jq -e 'has("ram") and (.ram.totalMb > 0)' <<<"$stats" >/dev/null 2>&1; then
  ok "memory is reported"
else
  bad "memory is reported"
fi

# MangoHud config writing, into a throwaway config dir.
tmp="$(mktemp -d)"
if XDG_CONFIG_HOME="$tmp" "$PLUGIN_DIR/bin/gc-mangohud" --position bottom-left \
     --metrics cpu,gpu,temps </dev/null >/dev/null 2>&1; then
  conf="$tmp/MangoHud/MangoHud.conf"
  if grep -q '^position=bottom-left' "$conf" 2>/dev/null && grep -q '^fps' "$conf" 2>/dev/null; then
    ok "mangohud config is written with the chosen corner"
  else
    bad "mangohud config is written with the chosen corner"
  fi
  # A second run must not duplicate the block.
  XDG_CONFIG_HOME="$tmp" "$PLUGIN_DIR/bin/gc-mangohud" --position top-left \
    --metrics cpu </dev/null >/dev/null 2>&1
  if [[ "$(grep -c 'begin game-center' "$conf" 2>/dev/null)" == "1" ]]; then
    ok "rewriting mangohud config replaces its block rather than stacking"
  else
    bad "rewriting mangohud config replaces its block rather than stacking"
  fi
else
  bad "mangohud config is written"
fi
rm -rf "$tmp"

# Structural checks on every controller family in PadArt.js: parts inside the
# canvas, keys the streamer actually emits, and face buttons that agree with
# the button map. See tests/art_check.py — it runs standalone too, which is
# what you want while adding a family.
art_out="$(python3 "$PLUGIN_DIR/tests/art_check.py" 2>&1)"
if [[ $? -eq 0 ]]; then
  ok "controller art is structurally sound"
else
  while IFS= read -r line; do [[ -n $line ]] && bad "art: $line"; done <<<"$art_out"
fi

echo
printf 'pass %d · fail %d · skip %d\n' "$PASS" "$FAIL" "$SKIP"
[[ $FAIL -eq 0 ]]
