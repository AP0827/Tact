"""Base class for Tact integrations.

Every capability in Tact lives in a self-contained integration *folder*:

    tact/agent/integrations/<name>/
    ├── __init__.py      # re-exports the integration class
    ├── integration.py   # class <Name>Integration(Integration)
    └── ...              # any helper files the app needs (state.py,
                         #   apps.py, detection.py, ...)

An integration owns four things:

  * ``name``       — stable identifier; becomes the action prefix
                    (``<name>.<action>``) and the snapshot key.
  * ``actions()``  — dict of action-id suffix -> handler callables.
                    Each handler receives the payload dict from the phone
                    and returns a plain dict result.
  * ``snapshot()`` — contribution to the state snapshot pushed to the
                    phone every few seconds.
  * ``monitor()``  — optional; called periodically by the StateMonitor.
                    Emit events (e.g. ``git.state_changed``) via the
                    EventBus when things change.

Adding a new capability (e.g. "figma", "video editing") is:
  1. create ``integrations/figma/`` with an ``integration.py`` exposing
     ``class FigmaIntegration(Integration)`` with ``name = "figma"``,
  2. import + instantiate it in ``ActionRegistry`` (actions.py).

Registration is explicit (good development practice): one import + one
line in ``ActionRegistry.integrations``. No changes to main.py or
monitoring.py are needed; native clients can add an optional platform view.
"""

from __future__ import annotations

from typing import Any, Callable

from ..events import EventBus


class Integration:
    """Base class: an integration is a self-contained capability bundle."""

    name: str = "integration"

    def actions(self) -> dict[str, Callable[[dict], Any]]:
        """Action-id suffixes -> handlers. Prefix is `self.name`."""
        return {}

    def snapshot(self) -> dict[str, Any]:
        """Contribution to the state snapshot pushed to the phone."""
        return {}

    def monitor(self, event_bus: EventBus) -> None:
        """Periodic state check; emit events when things change."""
        pass


def payload_str(payload: dict, key: str, default: Any = None) -> Any:
    return payload.get(key) if isinstance(payload, dict) else default


def payload_int(payload: dict, key: str, default: int) -> int:
    try:
        return int(payload_str(payload, key) or default)
    except (TypeError, ValueError):
        return default
