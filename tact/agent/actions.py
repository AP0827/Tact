from pydantic import BaseModel, HttpUrl, ValidationError
import logging
import sys
from pathlib import Path

from .events import EventBus
from .integrations.base import Integration
from .integrations.git import GitIntegration
from .integrations.vscode import VSCodeIntegration
from .integrations.system import SystemIntegration
from .integrations.media import MediaIntegration
from .integrations.docker import DockerIntegration
from .integrations.clipboard import ClipboardIntegration
from .integrations.context import ContextIntegration


class OpenUrlPayload(BaseModel):
    url: HttpUrl


class ActionRegistry:
    """Action dispatcher over self-registering integrations.

    Each integration contributes its actions via `Integration.actions()`;
    the full id is `<integration.name>.<suffix>`. Only cross-integration
    composites (actions that span two integrations) are registered here.
    Adding a capability = one new integration file + one line here.
    """

    def __init__(self, current_workspace_path=None):
        self.git = GitIntegration()
        self.vscode = VSCodeIntegration()
        self.system = SystemIntegration()
        self.media = MediaIntegration()
        self.docker = DockerIntegration()
        self.clipboard = ClipboardIntegration()
        self.context = ContextIntegration()

        self.integrations: list[Integration] = [
            self.system,
            self.vscode,
            self.git,
            self.media,
            self.docker,
            self.clipboard,
            self.context,
        ]
        self.event_bus = EventBus()
        self._current_workspace_path = current_workspace_path

        self._registry = {}
        for integration in self.integrations:
            for suffix, handler in integration.actions().items():
                self._registry[f"{integration.name}.{suffix}"] = handler

        # Cross-integration composites — deliberate exceptions, kept here.
        self._registry["system.set_workspace"] = self._set_workspace
        self._registry["media.open_spotify"] = self._media_open_spotify

        self.set_current_workspace_path(current_workspace_path)

    def set_current_workspace_path(self, path: str | None):
        """Propagate the workspace override to integrations that use it."""
        self._current_workspace_path = path
        for integration in self.integrations:
            if hasattr(integration, "workspace_path"):
                integration.workspace_path = path

    def execute(self, action_id: str, payload: dict):
        handler = self._registry.get(action_id)
        if not handler:
            return {"ok": False, "error": "unknown_action"}
        try:
            result = handler(payload or {})
            logging.info("action executed: %s payload=%s result=%s", action_id, payload, result)
            return {"ok": True, "result": result}
        except ValidationError as e:
            return {"ok": False, "error": e.errors()}
        except Exception as e:
            logging.exception("action execution failed")
            return {"ok": False, "error": str(e)}

    # -- composites -------------------------------------------------------

    def _set_workspace(self, payload: dict):
        path = payload.get("path") if isinstance(payload, dict) else None
        if not path:
            return {"ok": False, "error": "path_required"}
        p = Path(path)
        if not p.is_dir():
            return {"ok": False, "error": "not_a_directory"}
        resolved = str(p.resolve())
        self.set_current_workspace_path(resolved)
        return {"ok": True, "workspace": resolved}

    def _media_open_spotify(self, payload: dict):
        result = self.media.open_spotify()
        if not result.get("ok") and result.get("fallback"):
            return self.system.open_url(result["fallback"])
        return result