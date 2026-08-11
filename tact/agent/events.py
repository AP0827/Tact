from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, Optional
from datetime import datetime
import logging


@dataclass
class Event:
    """Base event."""
    event_type: str
    timestamp: float
    source: str
    title: str
    message: str
    data: dict[str, Any]

    def to_json(self) -> dict[str, Any]:
        return {
            "event_type": self.event_type,
            "timestamp": self.timestamp,
            "source": self.source,
            "title": self.title,
            "message": self.message,
            "data": self.data,
        }


class EventBus:
    """Simple event bus for broadcasting state changes."""

    def __init__(self):
        self._subscribers: dict[str, list[Callable]] = {}
        self._last_events: dict[str, Event] = {}

    def subscribe(self, event_type: str, callback: Callable[[Event], None]):
        """Subscribe to events of a given type."""
        if event_type not in self._subscribers:
            self._subscribers[event_type] = []
        self._subscribers[event_type].append(callback)

    def emit(self, event: Event):
        """Emit an event and notify all subscribers."""
        logging.info("event emitted: %s source=%s", event.event_type, event.source)
        self._last_events[event.event_type] = event

        subscribers = self._subscribers.get(event.event_type, [])
        for callback in subscribers:
            try:
                callback(event)
            except Exception:
                logging.exception("subscriber callback failed for %s", event.event_type)

    def emit_simple(self, event_type: str, source: str, title: str, message: str, data: dict[str, Any] | None = None):
        """Emit a simple event without constructing an Event object."""
        event = Event(
            event_type=event_type,
            timestamp=datetime.utcnow().timestamp(),
            source=source,
            title=title,
            message=message,
            data=data or {},
        )
        self.emit(event)

    def last_event(self, event_type: str) -> Optional[Event]:
        """Get the most recent event of a given type."""
        return self._last_events.get(event_type)
