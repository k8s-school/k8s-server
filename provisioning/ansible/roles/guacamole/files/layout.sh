#!/bin/bash
# /usr/local/bin/layout.sh — deployed by the guacamole role (Ansible).
#
# Tiles the two windows a participant works in side by side: the browser on
# the left half of the screen, the terminal on the right. Meant to be run from
# inside the XFCE desktop, once both windows are open.

# Run from an SSH session there is no X server to talk to, and xdotool fails
# with a cryptic "Can't open display" — say what is actually wrong instead.
if [ -z "${DISPLAY:-}" ]; then
    echo "layout.sh: no DISPLAY — run this from the graphical desktop, not over SSH" >&2
    exit 1
fi
for tool in xdotool wmctrl; do
    command -v "$tool" > /dev/null || { echo "layout.sh: $tool is missing" >&2; exit 1; }
done

sleep 1
read -r W H < <(xdotool getdisplaygeometry)
HALF=$((W / 2))
PANEL=32                 # hauteur du panneau XFCE
USABLE=$((H - PANEL))

place() {   # $1 = motif de titre, $2 = X
  id=$(xdotool search --name "$1" | tail -1)
  [ -z "$id" ] && return
  wmctrl -i -r "$id" -b remove,maximized_vert,maximized_horz
  xdotool windowmove "$id" "$2" 0
  xdotool windowsize "$id" "$HALF" "$USABLE"
}

place "Mozilla Firefox" 0
place "Terminal"        "$HALF"
