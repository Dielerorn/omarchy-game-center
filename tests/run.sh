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

echo "shell scripts"
for f in "$PLUGIN_DIR"/bin/*; do
  name="$(basename "$f")"
  if bash -n "$f" 2>/dev/null; then ok "$name parses"; else bad "$name parses"; fi
done
if command -v shellcheck >/dev/null; then
  for f in "$PLUGIN_DIR"/bin/*; do
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
printf 'pass %d · fail %d · skip %d\n' "$PASS" "$FAIL" "$SKIP"
[[ $FAIL -eq 0 ]]
