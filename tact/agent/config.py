import json
import secrets
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


CONFIG_DIR = Path.home() / ".tact"
CONFIG_FILE = CONFIG_DIR / "config.json"


@dataclass
class PairedDevice:
    device_id: str
    label: str
    paired_at: str
    last_seen: Optional[str] = None


class Config:
    """Local-first configuration and pairing persistence."""

    def __init__(self, config_path: Optional[Path] = None):
        self.config_path = config_path or CONFIG_FILE
        self._data = self._load()

    def _load(self) -> dict:
        if not self.config_path.exists():
            return {"paired_devices": [], "pairing_token": None, "pairing_token_expires": None}
        try:
            text = self.config_path.read_text(encoding="utf-8")
            return json.loads(text)
        except Exception:
            return {"paired_devices": [], "pairing_token": None, "pairing_token_expires": None}

    def _save(self) -> None:
        try:
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            self.config_path.write_text(json.dumps(self._data, indent=2), encoding="utf-8")
        except Exception:
            pass

    def generate_pairing_token(self, ttl_seconds: int = 300) -> str:
        token = secrets.token_urlsafe(16)
        self._data["pairing_token"] = token
        self._data["pairing_token_expires"] = (
            datetime.now(timezone.utc).timestamp() + ttl_seconds
        )
        self._save()
        return token

    def consume_pairing_token(self, token: str) -> bool:
        expected = self._data.get("pairing_token")
        expires = self._data.get("pairing_token_expires")
        if not expected or expected != token:
            return False
        if expires is None or datetime.now(timezone.utc).timestamp() > expires:
            self._data["pairing_token"] = None
            self._data["pairing_token_expires"] = None
            self._save()
            return False
        self._data["pairing_token"] = None
        self._data["pairing_token_expires"] = None
        self._save()
        return True

    def pair_device(self, device_id: str, label: str) -> PairedDevice:
        device = PairedDevice(
            device_id=device_id,
            label=label,
            paired_at=datetime.now(timezone.utc).isoformat(),
        )
        devices = self._data.get("paired_devices", [])
        devices = [d for d in devices if d.get("device_id") != device_id]
        devices.append(asdict(device))
        self._data["paired_devices"] = devices
        self._save()
        return device

    def unpair_device(self, device_id: str) -> bool:
        devices = self._data.get("paired_devices", [])
        new_devices = [d for d in devices if d.get("device_id") != device_id]
        if len(new_devices) == len(devices):
            return False
        self._data["paired_devices"] = new_devices
        self._save()
        return True

    def is_paired(self, device_id: str) -> bool:
        return any(
            d.get("device_id") == device_id
            for d in self._data.get("paired_devices", [])
        )

    def list_devices(self) -> list[PairedDevice]:
        return [PairedDevice(**d) for d in self._data.get("paired_devices", [])]

    def update_last_seen(self, device_id: str) -> None:
        devices = self._data.get("paired_devices", [])
        for d in devices:
            if d.get("device_id") == device_id:
                d["last_seen"] = datetime.now(timezone.utc).isoformat()
        self._data["paired_devices"] = devices
        self._save()
