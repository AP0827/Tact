from __future__ import annotations

import asyncio
import logging
from pathlib import Path

from .events import EventBus
from .integrations.git import GitIntegration
from .integrations.vscode import VSCodeIntegration


class StateMonitor:
    """Monitors Git/VS Code state and emits events on changes."""

    def __init__(self, event_bus: EventBus):
        self.event_bus = event_bus
        self.git = GitIntegration()
        self.vscode = VSCodeIntegration()
        self._last_git_state: dict | None = None
        self._last_vscode_state: dict | None = None

    async def monitor_loop(self, interval: float = 10.0):
        """Periodically check for state changes and emit events."""
        while True:
            try:
                await asyncio.sleep(interval)
                self._check_git_state()
                self._check_vscode_state()
            except Exception:
                logging.exception("monitor loop error")

    def _check_git_state(self):
        """Check if Git state has changed and emit events."""
        try:
            root = self.git.discover_root(Path.cwd())
            if root is None:
                return

            current = self.git.status(root)
            if not current.get("available"):
                return

            # Emit event on changes
            if self._last_git_state is None or self._last_git_state != current:
                self.event_bus.emit_simple(
                    "git.state_changed",
                    "git",
                    f"Git: {current.get('branch', 'unknown')}",
                    f"{current.get('changed_files', 0)} files changed" if not current.get("clean") else "clean",
                    current,
                )
                self._last_git_state = current
        except Exception:
            logging.exception("git state check failed")

    def _check_vscode_state(self):
        """Check if VS Code is running and emit events."""
        try:
            current = {"running": self.vscode.is_running(), "available": self.vscode.is_available()}
            if self._last_vscode_state is None or self._last_vscode_state != current:
                self.event_bus.emit_simple(
                    "vscode.state_changed",
                    "vscode",
                    "VS Code",
                    "running" if current["running"] else "stopped",
                    current,
                )
                self._last_vscode_state = current
        except Exception:
            logging.exception("vscode state check failed")
