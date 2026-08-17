from __future__ import annotations

import shutil
import subprocess
from typing import Any, Optional

from ..base import Integration, payload_int, payload_str


class DockerIntegration(Integration):
    """Docker container status and lifecycle controls via the CLI.

    Shells out to `docker` (no SDK dependency). Detects the docker daemon's
    availability; if the socket is unreachable (e.g. user not in the docker
    group) it reports `available: False` so the UI can degrade gracefully.
    """

    name = "docker"

    def actions(self) -> dict[str, Any]:
        return {
            "status": lambda p: self.containers(),
            "start": lambda p: self.start(payload_str(p, "name")),
            "stop": lambda p: self.stop(payload_str(p, "name")),
            "restart": lambda p: self.restart(payload_str(p, "name")),
            "logs": lambda p: self.logs(payload_str(p, "name"), tail=payload_int(p, "tail", 80)),
        }

    def snapshot(self) -> dict[str, Any]:
        return self.containers()

    def monitor(self, event_bus) -> None:
        """Emit `docker.state_changed` when container states change."""
        current = self.containers()
        if not current.get("available"):
            if self._last_state not in (None, current):
                event_bus.emit_simple(
                    "docker.state_changed",
                    "docker",
                    "Docker",
                    current.get("error") or "unavailable",
                    current,
                )
                self._last_state = current
            return

        states = {c["name"]: c["state"] for c in current.get("containers", [])}
        if self._last_state != states:
            if self._last_state is not None:
                event_bus.emit_simple(
                    "docker.state_changed",
                    "docker",
                    "Docker",
                    ", ".join(f"{name}: {state}" for name, state in states.items())
                    or "no containers",
                    current,
                )
            self._last_state = states

    _last_state: Any = None

    def _docker(self) -> Optional[str]:
        return shutil.which("docker")

    def is_available(self) -> bool:
        return self._docker() is not None

    def _run(self, args: list[str]) -> tuple[int, str, str]:
        binary = self._docker()
        if binary is None:
            return 1, "", "docker_not_found"
        try:
            completed = subprocess.run(
                [binary, *args],
                capture_output=True,
                text=True,
                check=False,
                timeout=15,
            )
            return completed.returncode, completed.stdout.strip(), completed.stderr.strip()
        except (OSError, subprocess.TimeoutExpired) as exc:
            return 1, "", str(exc)

    def containers(self) -> dict[str, Any]:
        """List all containers with state, image, and uptime."""
        rc, out, err = self._run(
            [
                "ps",
                "-a",
                "--format",
                "{{.Names}}\t{{.State}}\t{{.Image}}\t{{.Status}}",
            ]
        )
        if rc != 0:
            if "permission denied" in err or "connect: permission denied" in err:
                return {"available": False, "error": "docker_permission_denied"}
            return {"available": False, "error": err or "docker_failed"}

        containers = []
        for line in out.splitlines():
            parts = line.split("\t")
            if len(parts) < 4:
                continue
            name, state, image, status = parts[0], parts[1], parts[2], parts[3]
            containers.append(
                {
                    "name": name,
                    "state": state,  # running | exited | paused | restarting
                    "image": image,
                    "status": status,
                }
            )
        return {"available": True, "containers": containers, "count": len(containers)}

    def start(self, name: str) -> dict[str, Any]:
        return self._lifecycle("start", name)

    def stop(self, name: str) -> dict[str, Any]:
        return self._lifecycle("stop", name)

    def restart(self, name: str) -> dict[str, Any]:
        return self._lifecycle("restart", name)

    def _lifecycle(self, verb: str, name: str) -> dict[str, Any]:
        if not name or not name.strip():
            return {"ok": False, "error": "container_name_required"}
        rc, out, err = self._run([verb, name])
        if rc != 0:
            return {"ok": False, "container": name, "error": err or "docker_failed"}
        return {"ok": True, "container": name, "action": verb, "output": out}

    def logs(self, name: str, tail: int = 80) -> dict[str, Any]:
        """Fetch recent container logs (last `tail` lines)."""
        if not name or not name.strip():
            return {"ok": False, "error": "container_name_required"}
        rc, out, err = self._run(["logs", "--tail", str(int(tail)), name])
        if rc != 0:
            return {"ok": False, "container": name, "error": err or "docker_failed"}
        return {"ok": True, "container": name, "logs": out}