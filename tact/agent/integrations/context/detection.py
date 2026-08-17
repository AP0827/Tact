"""X11 active-window detection for the Context Engine.

Reads the `_NET_ACTIVE_WINDOW` root property via xprop, then WM_CLASS and
_NET_WM_NAME for the focused window. Falls back to `xdotool getactivewindow`
when xprop is absent. Wayland and headless sessions return None (the
integration degrades gracefully).

Swap this file for a Wayland backend (wlrctl/swaymsg) later — nothing else
in the context integration changes.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from typing import Any, Optional


def active_window() -> Optional[dict[str, Any]]:
    """Return {id, class, title} for the focused window, or None."""
    if not os.environ.get("DISPLAY"):
        return None
    wid = active_window_id()
    if not wid:
        return None
    try:
        info = subprocess.run(
            ["xprop", "-id", wid, "_NET_WM_NAME", "WM_CLASS"],
            capture_output=True,
            text=True,
            check=False,
            timeout=3,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    cls = re.search(r'WM_CLASS\(STRING\) = "([^"]+)"', info.stdout)
    name = re.search(r'_NET_WM_NAME\(UTF8_STRING\) = "([^"]*)"', info.stdout)
    if cls is None and name is None:
        return None
    return {
        "id": wid,
        "class": cls.group(1).lower() if cls else None,
        "title": name.group(1) if name else "",
    }


def active_window_id() -> Optional[str]:
    if shutil.which("xprop"):
        try:
            out = subprocess.run(
                ["xprop", "-root", "_NET_ACTIVE_WINDOW"],
                capture_output=True,
                text=True,
                check=False,
                timeout=3,
            )
            m = re.search(r"window id # (0x[0-9a-fA-F]+)", out.stdout)
            if m:
                return m.group(1)
        except (OSError, subprocess.TimeoutExpired):
            pass
    if shutil.which("xdotool"):
        try:
            out = subprocess.run(
                ["xdotool", "getactivewindow"],
                capture_output=True,
                text=True,
                check=False,
                timeout=3,
            )
            wid = out.stdout.strip()
            return wid if wid and wid != "0" else None
        except (OSError, subprocess.TimeoutExpired):
            pass
    return None