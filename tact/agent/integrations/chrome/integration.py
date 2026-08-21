"""Chrome browser controls (Phase 3.4).

Sends key combos to the *focused* Chrome window via xdotool. The Context
Engine guarantees Chrome is the active app when this surface is shown, so
keystrokes land in the right place without a debugging-port CDP connection.
CDP (richer state: tab title/URL) is a later enhancement; it requires Chrome
launched with --remote-debugging-port.

Swap the xdotool backend for a CDP client later — nothing else in the
surface definitions changes.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from typing import Any

from ..base import Integration


class ChromeIntegration(Integration):
    """Browser navigation + tab controls for the Chrome surface."""

    name = "chrome"

    def actions(self) -> dict[str, Any]:
        return {
            "back": lambda p: self._key("alt+Left"),
            "forward": lambda p: self._key("alt+Right"),
            "refresh": lambda p: self._key("ctrl+r"),
            "new_tab": lambda p: self._key("ctrl+t"),
            "close_tab": lambda p: self._key("ctrl+w"),
            "reopen_tab": lambda p: self._key("ctrl+shift+t"),
            "copy_url": lambda p: self._key("ctrl+l", then_key="ctrl+c"),
            "devtools": lambda p: self._key("ctrl+shift+i"),
        }

    def snapshot(self) -> dict[str, Any]:
        return {"available": self._available()}

    def _available(self) -> bool:
        return bool(shutil.which("xdotool")) and bool(os.environ.get("DISPLAY"))

    def _key(self, key: str, then_key: str | None = None) -> dict[str, Any]:
        if not self._available():
            return {"ok": False, "error": "xdotool_unavailable"}
        try:
            subprocess.run(
                ["xdotool", "key", "--clearmodifiers", key],
                capture_output=True,
                text=True,
                check=False,
                timeout=3,
            )
            if then_key:
                subprocess.run(
                    ["xdotool", "key", "--clearmodifiers", then_key],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=3,
                )
            return {"ok": True, "key": key, "then_key": then_key}
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"ok": False, "error": str(exc)}