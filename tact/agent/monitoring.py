from __future__ import annotations

import asyncio
import logging

from .events import EventBus
from .integrations.base import Integration


class StateMonitor:
    """Generic state monitor.

    Runs every `interval` seconds and delegates to each integration's
    `monitor(event_bus)` method. Integrations decide what to check and
    which events to emit (e.g. `git.state_changed`). Adding a new
    monitored capability requires no changes here.
    """

    def __init__(self, event_bus: EventBus, integrations: list[Integration]):
        self.event_bus = event_bus
        self.watchers = [
            integration
            for integration in integrations
            if type(integration).monitor is not Integration.monitor
        ]

    async def monitor_loop(self, interval: float = 10.0):
        """Periodically check for state changes and emit events."""
        while True:
            try:
                await asyncio.sleep(interval)
                for watcher in self.watchers:
                    try:
                        watcher.monitor(self.event_bus)
                    except Exception:
                        logging.exception("%s monitor failed", watcher.name)
            except Exception:
                logging.exception("monitor loop error")