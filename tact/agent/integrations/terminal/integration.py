"""Terminal surface controls (Phase 3.3).

Keystroke-level controls for the focused terminal via xdotool — safe because
the Context Engine guarantees the terminal is the active app when this
surface shows:

* clear  — Ctrl+L (shell clear-screen, works in bash/zsh/fish)
* rerun  — Up + Enter (re-executes the last command from history)
* kill   — Ctrl+C (interrupts the foreground job)

"Copy output" needs terminal scrollback access (konsole DBus / a tty bridge)
and lands with Phase 9 terminal jobs; the state card meanwhile surfaces the
window title (most terminals put the running command there) plus project and
branch from the Context Engine.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from typing import Any

from ..base import Integration


class TerminalIntegration(Integration):
    """Clear / rerun / kill for the focused terminal window."""

    name = "terminal"

    def actions(self) -> dict[str, Any]:
        return {
            "clear": lambda p: self._key("ctrl+l"),
            "rerun": lambda p: self._rerun(),
            "kill": lambda p: self._key("ctrl+c"),
        }

    def snapshot(self) -> dict[str, Any]:
        return {"available": self._available()}

    def _available(self) -> bool:
        return bool(shutil.which("xdotool")) and bool(os.environ.get("DISPLAY"))

    def _key(self, key: str) -> dict[str, Any]:
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
            return {"ok": True, "key": key}
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"ok": False, "error": str(exc)}

    def _rerun(self) -> dict[str, Any]:
        if not self._available():
            return {"ok": False, "error": "xdotool_unavailable"}
        try:
            for key in ("Up", "Return"):
                subprocess.run(
                    ["xdotool", "key", "--clearmodifiers", key],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=3,
                )
            return {"ok": True, "keys": ["Up", "Return"]}
        except (OSError, subprocess.TimeoutExpired) as exc:
            return {"ok": False, "error": str(exc)}