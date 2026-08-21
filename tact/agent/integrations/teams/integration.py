"""Teams meeting controls (Phase 3.6).

Activates the Teams window (wmctrl -a, proven reliable on this stack for
`open_spotify`) then sends the app's key combo via xdotool:
mute Ctrl+Shift+M, camera Ctrl+Shift+O, share Ctrl+Shift+E, leave
Ctrl+Shift+B. Same approach works for any meeting app with key combos;
a proper integration (SDK/accessibility bridge) is a later enhancement.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from typing import Any

from ..base import Integration


class TeamsIntegration(Integration):
    """Meeting controls for the Teams surface."""

    name = "teams"

    _COMBO_MAP = {
        "mute": "ctrl+shift+m",
        "camera": "ctrl+shift+o",
        "share": "ctrl+shift+e",
        "leave": "ctrl+shift+b",
    }

    def actions(self) -> dict[str, Any]:
        return {
            name: (lambda p, combo=combo: self._combo(combo))
            for name, combo in self._COMBO_MAP.items()
        }

    def snapshot(self) -> dict[str, Any]:
        return {"available": self._available()}

    def _available(self) -> bool:
        return bool(
            (shutil.which("wmctrl") or shutil.which("xdotool"))
            and os.environ.get("DISPLAY")
        )

    def _combo(self, combo: str) -> dict[str, Any]:
        if not self._available():
            return {"ok": False, "error": "window_tools_unavailable"}
        if shutil.which("wmctrl"):
            try:
                subprocess.run(
                    ["wmctrl", "-a", "Teams"],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=5,
                )
            except (OSError, subprocess.TimeoutExpired):
                pass
        try:
            subprocess.run(
                ["xdotool", "key", "--clearmodifiers", combo],
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )
            return {"ok": True, "key": combo}
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"ok": False, "error": str(exc)}