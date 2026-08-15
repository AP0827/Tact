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


@dataclass
class PendingPairing:
    pending_id: str
    device_id: str
    label: str
    created_at: str
    otp: str
    otp_expires: float


class Config:
    """Persistent local configuration and pairing state."""

    def __init__(self, config_path: Optional[Path] = None):
        self.config_path = config_path or CONFIG_FILE
        self._data = self._load()

    @staticmethod
    def _defaults() -> dict:
        return {
            "paired_devices": [],
            "pending_pairings": [],
            "pairing_token": None,
            "pairing_token_expires": None,
        }

    def _load(self) -> dict:
        if not self.config_path.exists():
            return self._defaults()

        try:
            with self.config_path.open("r", encoding="utf-8") as f:
                data = json.load(f)

            if not isinstance(data, dict):
                return self._defaults()

            defaults = self._defaults()
            defaults.update({
                "paired_devices": data.get("paired_devices", []),
                "pending_pairings": data.get("pending_pairings", []),
                "pairing_token": data.get("pairing_token"),
                "pairing_token_expires": data.get("pairing_token_expires"),
            })
            return defaults
        except (OSError, json.JSONDecodeError, TypeError):
            return self._defaults()

    def _save(self) -> None:
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        temp_path = self.config_path.with_suffix(".tmp")

        with temp_path.open("w", encoding="utf-8") as f:
            json.dump(self._data, f, indent=2)
            f.write("\n")

        temp_path.replace(self.config_path)

    def generate_pairing_token(self, ttl_seconds: int = 300) -> str:
        token = f"{secrets.randbelow(1000000):06d}"
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

        if expires is None or datetime.now(timezone.utc).timestamp() > float(expires):
            self._data["pairing_token"] = None
            self._data["pairing_token_expires"] = None
            self._save()
            return False

        self._data["pairing_token"] = None
        self._data["pairing_token_expires"] = None
        self._save()
        return True

    def create_pending_pairing(
        self,
        otp: str,
        device_id: str,
        label: str,
        ttl_seconds: int = 300,
    ) -> PendingPairing:
        now = datetime.now(timezone.utc)
        pending = PendingPairing(
            pending_id=secrets.token_urlsafe(8),
            device_id=device_id,
            label=label,
            created_at=now.isoformat(),
            otp=otp,
            otp_expires=now.timestamp() + ttl_seconds,
        )

        pendings = [
            p for p in self._data.get("pending_pairings", [])
            if p.get("device_id") != device_id
        ]
        pendings.append(asdict(pending))
        self._data["pending_pairings"] = pendings
        self._save()
        return pending

    def get_pending_pairing(self, pending_id: str) -> Optional[PendingPairing]:
        for p in self._data.get("pending_pairings", []):
            if p.get("pending_id") == pending_id:
                return PendingPairing(**p)
        return None

    def approve_pending_pairing(
        self,
        pending_id: str,
    ) -> Optional[PairedDevice]:
        pending = self.get_pending_pairing(pending_id)

        if pending is None:
            return None

        if datetime.now(timezone.utc).timestamp() > float(pending.otp_expires):
            self._data["pending_pairings"] = [
                p
                for p in self._data.get("pending_pairings", [])
                if p.get("pending_id") != pending_id
            ]
            self._save()
            return None

        device = self.pair_device(
            pending.device_id,
            pending.label,
        )

        self._data["pending_pairings"] = [
            p
            for p in self._data.get("pending_pairings", [])
            if p.get("pending_id") != pending_id
        ]
        self._save()
        return device

    def pair_device(self, device_id: str, label: str) -> PairedDevice:
        device = PairedDevice(
            device_id=device_id,
            label=label,
            paired_at=datetime.now(timezone.utc).isoformat(),
        )

        devices = [
            d
            for d in self._data.get("paired_devices", [])
            if d.get("device_id") != device_id
        ]
        devices.append(asdict(device))
        self._data["paired_devices"] = devices
        self._save()
        return device

    def unpair_device(self, device_id: str) -> bool:
        devices = self._data.get("paired_devices", [])
        new_devices = [
            d
            for d in devices
            if d.get("device_id") != device_id
        ]

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
        return [
            PairedDevice(**d)
            for d in self._data.get("paired_devices", [])
        ]

    def update_last_seen(self, device_id: str) -> None:
        devices = self._data.get("paired_devices", [])

        for d in devices:
            if d.get("device_id") == device_id:
                d["last_seen"] = datetime.now(timezone.utc).isoformat()

        self._data["paired_devices"] = devices
        self._save()
