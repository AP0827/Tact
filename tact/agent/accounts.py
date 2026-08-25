from __future__ import annotations

import hashlib
import os
import secrets
import sqlite3
import threading
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

import jwt
from jwt import PyJWKClient


ACCOUNT_DB = Path.home() / ".tact" / "accounts.sqlite3"
SESSION_LIFETIME = timedelta(days=30)
ACTIVE_WINDOW = timedelta(minutes=2)


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso_now() -> str:
    return _utc_now().isoformat()


def _normalise_email(value: str) -> str:
    return value.strip().casefold()


def _hash_password(password: str, salt: Optional[bytes] = None) -> tuple[str, str]:
    if len(password) < 10:
        raise ValueError("password_too_short")
    actual_salt = salt or secrets.token_bytes(16)
    digest = hashlib.scrypt(
        password.encode("utf-8"),
        salt=actual_salt,
        n=2**14,
        r=8,
        p=1,
        dklen=32,
    )
    return actual_salt.hex(), digest.hex()


def _verify_password(password: str, salt_hex: str, digest_hex: str) -> bool:
    try:
        _, candidate = _hash_password(password, bytes.fromhex(salt_hex))
    except (ValueError, TypeError):
        return False
    return secrets.compare_digest(candidate, digest_hex)


@dataclass(frozen=True)
class AuthSession:
    token: str
    account_id: str
    email: str
    display_name: str
    provider: str
    expires_at: str


@dataclass(frozen=True)
class AccountDevice:
    device_id: str
    label: str
    platform: str
    device_type: str
    model: str
    host: Optional[str]
    port: Optional[int]
    last_seen: str
    active: bool
    can_connect: bool


class AccountStore:
    """Durable identity, session, and account-device registry."""

    def __init__(self, database_path: Optional[Path] = None):
        self.database_path = database_path or ACCOUNT_DB
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(
            self.database_path,
            check_same_thread=False,
        )
        self._connection.row_factory = sqlite3.Row
        self._lock = threading.RLock()
        self._migrate()

    def close(self) -> None:
        with self._lock:
            self._connection.close()

    def _migrate(self) -> None:
        with self._lock, self._connection:
            self._connection.executescript(
                """
                PRAGMA journal_mode = WAL;
                PRAGMA foreign_keys = ON;

                CREATE TABLE IF NOT EXISTS accounts (
                    account_id TEXT PRIMARY KEY,
                    email TEXT NOT NULL UNIQUE,
                    display_name TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS identities (
                    provider TEXT NOT NULL,
                    subject TEXT NOT NULL,
                    account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
                    password_salt TEXT,
                    password_hash TEXT,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (provider, subject)
                );

                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY,
                    account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
                    provider TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    expires_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS account_devices (
                    account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
                    device_id TEXT NOT NULL,
                    label TEXT NOT NULL,
                    platform TEXT NOT NULL,
                    device_type TEXT NOT NULL,
                    model TEXT NOT NULL,
                    host TEXT,
                    port INTEGER,
                    last_seen TEXT NOT NULL,
                    PRIMARY KEY (account_id, device_id)
                );
                """
            )

    def register_email(
        self,
        email: str,
        password: str,
        display_name: str = "",
    ) -> AuthSession:
        normalised = _normalise_email(email)
        if "@" not in normalised or normalised.startswith("@"):
            raise ValueError("invalid_email")
        salt, digest = _hash_password(password)
        account_id = secrets.token_urlsafe(18)
        now = _iso_now()
        name = display_name.strip() or normalised.split("@", 1)[0]
        with self._lock, self._connection:
            if self._connection.execute(
                "SELECT 1 FROM accounts WHERE email = ?", (normalised,)
            ).fetchone():
                raise ValueError("email_already_registered")
            self._connection.execute(
                "INSERT INTO accounts VALUES (?, ?, ?, ?)",
                (account_id, normalised, name, now),
            )
            self._connection.execute(
                "INSERT INTO identities VALUES ('email', ?, ?, ?, ?, ?)",
                (normalised, account_id, salt, digest, now),
            )
        return self._create_session(account_id, "email")

    def authenticate_email(self, email: str, password: str) -> Optional[AuthSession]:
        normalised = _normalise_email(email)
        with self._lock:
            row = self._connection.execute(
                """
                SELECT i.account_id, i.password_salt, i.password_hash
                FROM identities i
                WHERE i.provider = 'email' AND i.subject = ?
                """,
                (normalised,),
            ).fetchone()
        if not row or not _verify_password(
            password,
            row["password_salt"],
            row["password_hash"],
        ):
            return None
        return self._create_session(row["account_id"], "email")

    def authenticate_provider(
        self,
        provider: str,
        claims: dict[str, Any],
    ) -> AuthSession:
        if provider not in {"apple", "google"}:
            raise ValueError("unsupported_provider")
        subject = str(claims.get("sub") or "").strip()
        email = _normalise_email(str(claims.get("email") or ""))
        if not subject or not email:
            raise ValueError("provider_identity_incomplete")
        display_name = str(claims.get("name") or "").strip() or email.split("@", 1)[0]
        now = _iso_now()
        with self._lock, self._connection:
            identity = self._connection.execute(
                "SELECT account_id FROM identities WHERE provider = ? AND subject = ?",
                (provider, subject),
            ).fetchone()
            if identity:
                account_id = identity["account_id"]
            else:
                account = self._connection.execute(
                    "SELECT account_id FROM accounts WHERE email = ?",
                    (email,),
                ).fetchone()
                if account:
                    account_id = account["account_id"]
                else:
                    account_id = secrets.token_urlsafe(18)
                    self._connection.execute(
                        "INSERT INTO accounts VALUES (?, ?, ?, ?)",
                        (account_id, email, display_name, now),
                    )
                self._connection.execute(
                    "INSERT INTO identities VALUES (?, ?, ?, NULL, NULL, ?)",
                    (provider, subject, account_id, now),
                )
        return self._create_session(account_id, provider)

    def _create_session(self, account_id: str, provider: str) -> AuthSession:
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        created = _utc_now()
        expires = created + SESSION_LIFETIME
        with self._lock, self._connection:
            self._connection.execute(
                "INSERT INTO sessions VALUES (?, ?, ?, ?, ?)",
                (
                    token_hash,
                    account_id,
                    provider,
                    created.isoformat(),
                    expires.isoformat(),
                ),
            )
            account = self._connection.execute(
                "SELECT email, display_name FROM accounts WHERE account_id = ?",
                (account_id,),
            ).fetchone()
        return AuthSession(
            token=token,
            account_id=account_id,
            email=account["email"],
            display_name=account["display_name"],
            provider=provider,
            expires_at=expires.isoformat(),
        )

    def session(self, token: str) -> Optional[AuthSession]:
        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        with self._lock:
            row = self._connection.execute(
                """
                SELECT s.account_id, s.provider, s.expires_at,
                       a.email, a.display_name
                FROM sessions s
                JOIN accounts a ON a.account_id = s.account_id
                WHERE s.token_hash = ?
                """,
                (token_hash,),
            ).fetchone()
        if not row:
            return None
        if datetime.fromisoformat(row["expires_at"]) <= _utc_now():
            self.revoke_session(token)
            return None
        return AuthSession(
            token=token,
            account_id=row["account_id"],
            email=row["email"],
            display_name=row["display_name"],
            provider=row["provider"],
            expires_at=row["expires_at"],
        )

    def revoke_session(self, token: str) -> None:
        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        with self._lock, self._connection:
            self._connection.execute(
                "DELETE FROM sessions WHERE token_hash = ?",
                (token_hash,),
            )

    def upsert_device(
        self,
        account_id: str,
        device_id: str,
        label: str,
        platform: str,
        device_type: str,
        model: str = "",
        host: Optional[str] = None,
        port: Optional[int] = None,
    ) -> AccountDevice:
        if not device_id.strip() or not label.strip():
            raise ValueError("device_id_and_label_required")
        platform_value = platform.strip().lower() or "unknown"
        type_value = device_type.strip().lower()
        if type_value not in {"phone", "tablet", "desktop", "laptop"}:
            raise ValueError("invalid_device_type")
        now = _iso_now()
        with self._lock, self._connection:
            self._connection.execute(
                """
                INSERT INTO account_devices
                    (account_id, device_id, label, platform, device_type,
                     model, host, port, last_seen)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(account_id, device_id) DO UPDATE SET
                    label = excluded.label,
                    platform = excluded.platform,
                    device_type = excluded.device_type,
                    model = excluded.model,
                    host = excluded.host,
                    port = excluded.port,
                    last_seen = excluded.last_seen
                """,
                (
                    account_id,
                    device_id.strip(),
                    label.strip(),
                    platform_value,
                    type_value,
                    model.strip(),
                    host.strip() if host else None,
                    port,
                    now,
                ),
            )
        return self.device(account_id, device_id)  # type: ignore[return-value]

    def device(self, account_id: str, device_id: str) -> Optional[AccountDevice]:
        with self._lock:
            row = self._connection.execute(
                """
                SELECT * FROM account_devices
                WHERE account_id = ? AND device_id = ?
                """,
                (account_id, device_id),
            ).fetchone()
        return self._device_from_row(row) if row else None

    def list_devices(self, account_id: str) -> list[AccountDevice]:
        with self._lock:
            rows = self._connection.execute(
                """
                SELECT * FROM account_devices
                WHERE account_id = ?
                ORDER BY last_seen DESC, label COLLATE NOCASE
                """,
                (account_id,),
            ).fetchall()
        return [self._device_from_row(row) for row in rows]

    def remove_device(self, account_id: str, device_id: str) -> bool:
        with self._lock, self._connection:
            cursor = self._connection.execute(
                "DELETE FROM account_devices WHERE account_id = ? AND device_id = ?",
                (account_id, device_id),
            )
        return cursor.rowcount > 0

    @staticmethod
    def _device_from_row(row: sqlite3.Row) -> AccountDevice:
        last_seen = datetime.fromisoformat(row["last_seen"])
        active = _utc_now() - last_seen <= ACTIVE_WINDOW
        can_connect = bool(
            row["host"]
            and row["port"]
            and row["device_type"] in {"desktop", "laptop"}
        )
        return AccountDevice(
            device_id=row["device_id"],
            label=row["label"],
            platform=row["platform"],
            device_type=row["device_type"],
            model=row["model"],
            host=row["host"],
            port=row["port"],
            last_seen=row["last_seen"],
            active=active,
            can_connect=can_connect,
        )

    @staticmethod
    def public_session(session: AuthSession) -> dict[str, Any]:
        return asdict(session)


class ProviderTokenVerifier:
    """Verifies Apple and Google OpenID Connect identity tokens."""

    PROVIDERS = {
        "apple": {
            "jwks": "https://appleid.apple.com/auth/keys",
            "issuer": "https://appleid.apple.com",
            "audience_env": "TACT_APPLE_CLIENT_ID",
            "algorithms": ["RS256"],
        },
        "google": {
            "jwks": "https://www.googleapis.com/oauth2/v3/certs",
            "issuer": ["accounts.google.com", "https://accounts.google.com"],
            "audience_env": "TACT_GOOGLE_CLIENT_ID",
            "algorithms": ["RS256"],
        },
    }

    def verify(self, provider: str, identity_token: str) -> dict[str, Any]:
        configuration = self.PROVIDERS.get(provider)
        if not configuration:
            raise ValueError("unsupported_provider")
        audience = os.environ.get(str(configuration["audience_env"]), "").strip()
        if not audience:
            raise ValueError(f"{provider}_client_id_not_configured")
        signing_key = PyJWKClient(str(configuration["jwks"])).get_signing_key_from_jwt(
            identity_token
        )
        claims = jwt.decode(
            identity_token,
            signing_key.key,
            algorithms=configuration["algorithms"],
            audience=audience,
            issuer=configuration["issuer"],
            options={"require": ["exp", "iat", "iss", "aud", "sub"]},
        )
        if provider == "google" and not claims.get("email_verified"):
            raise ValueError("provider_email_not_verified")
        return claims
