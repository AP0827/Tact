from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

from tact.agent.config import Config, PairedDevice, PendingPairing
from tact.agent.events import Event, EventBus
from tact.agent.integrations.system import SystemIntegration
from tact.agent.actions import ActionRegistry
from tact.agent.accounts import AccountStore


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / "config.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_generate_6_digit_otp(self):
        config = Config(self.path)
        token = config.generate_pairing_token()
        self.assertTrue(token.isdigit())
        self.assertEqual(len(token), 6)

    def test_consume_valid_otp(self):
        config = Config(self.path)
        token = config.generate_pairing_token()
        self.assertTrue(config.consume_pairing_token(token))
        self.assertFalse(config.consume_pairing_token(token))

    def test_expired_otp_rejected(self):
        config = Config(self.path)
        token = config.generate_pairing_token(ttl_seconds=-1)
        self.assertFalse(config.consume_pairing_token(token))

    def test_pair_and_list_devices(self):
        config = Config(self.path)
        config.generate_pairing_token()
        config.consume_pairing_token(config._data["pairing_token"])
        device = config.pair_device("dev-1", "Phone")
        self.assertEqual(device.device_id, "dev-1")
        devices = config.list_devices()
        self.assertEqual(len(devices), 1)
        self.assertEqual(devices[0].label, "Phone")

    def test_unpair_device(self):
        config = Config(self.path)
        config.pair_device("dev-1", "Phone")
        self.assertTrue(config.is_paired("dev-1"))
        self.assertTrue(config.unpair_device("dev-1"))
        self.assertFalse(config.is_paired("dev-1"))

    def test_persistence_across_instances(self):
        config = Config(self.path)
        config.generate_pairing_token()
        config.consume_pairing_token(config._data["pairing_token"])
        config.pair_device("dev-1", "Phone")

        config2 = Config(self.path)
        devices = config2.list_devices()

        self.assertEqual(len(devices), 1)
        self.assertEqual(devices[0].device_id, "dev-1")
        self.assertEqual(devices[0].label, "Phone")

    def test_create_and_approve_pending_pairing(self):
        config = Config(self.path)
        otp = config.generate_pairing_token()
        config.consume_pairing_token(otp)
        pending = config.create_pending_pairing(otp, "dev-1", "Phone")
        self.assertEqual(pending.device_id, "dev-1")
        self.assertEqual(len(config._data.get("pending_pairings", [])), 1)
        device = config.approve_pending_pairing(pending.pending_id)
        self.assertIsNotNone(device)
        self.assertEqual(device.device_id, "dev-1")
        self.assertEqual(len(config._data.get("pending_pairings", [])), 0)
        self.assertTrue(config.is_paired("dev-1"))

    def test_reject_pending_pairing(self):
        config = Config(self.path)
        otp = config.generate_pairing_token()
        config.consume_pairing_token(otp)
        pending = config.create_pending_pairing(otp, "dev-1", "Phone")
        pendings = config._data.get("pending_pairings", [])
        new_pendings = [p for p in pendings if p.get("pending_id") != pending.pending_id]
        config._data["pending_pairings"] = new_pendings
        config._save()
        self.assertIsNone(config.get_pending_pairing(pending.pending_id))


class AccountStoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.store = AccountStore(Path(self.tmp.name) / "accounts.sqlite3")

    def tearDown(self):
        self.store.close()
        self.tmp.cleanup()

    def test_email_registration_login_and_session_expiry_boundary(self):
        registered = self.store.register_email(
            "Developer@Example.com",
            "correct-horse-battery-staple",
            "Developer",
        )
        self.assertEqual(registered.email, "developer@example.com")
        self.assertIsNotNone(self.store.session(registered.token))

        authenticated = self.store.authenticate_email(
            "developer@example.com",
            "correct-horse-battery-staple",
        )
        self.assertIsNotNone(authenticated)
        self.assertEqual(authenticated.account_id, registered.account_id)
        self.assertIsNone(
            self.store.authenticate_email("developer@example.com", "wrong-password")
        )

    def test_provider_identity_links_to_existing_email_account(self):
        email_session = self.store.register_email(
            "developer@example.com",
            "correct-horse-battery-staple",
        )
        provider_session = self.store.authenticate_provider(
            "google",
            {
                "sub": "google-subject",
                "email": "developer@example.com",
                "email_verified": True,
            },
        )
        self.assertEqual(provider_session.account_id, email_session.account_id)

    def test_devices_are_scoped_to_account_and_expose_connectability(self):
        first = self.store.register_email(
            "first@example.com",
            "correct-horse-battery-staple",
        )
        second = self.store.register_email(
            "second@example.com",
            "correct-horse-battery-staple",
        )
        registered = self.store.upsert_device(
            first.account_id,
            "mac-1",
            "Studio Mac",
            "macos",
            "desktop",
            "Mac Studio",
            "192.168.1.42",
            8000,
        )
        self.assertTrue(registered.active)
        self.assertTrue(registered.can_connect)
        self.assertEqual(len(self.store.list_devices(first.account_id)), 1)
        self.assertEqual(self.store.list_devices(second.account_id), [])

    def test_logout_revokes_only_requested_session(self):
        first = self.store.register_email(
            "developer@example.com",
            "correct-horse-battery-staple",
        )
        second = self.store.authenticate_email(
            "developer@example.com",
            "correct-horse-battery-staple",
        )
        self.store.revoke_session(first.token)
        self.assertIsNone(self.store.session(first.token))
        self.assertIsNotNone(self.store.session(second.token))


class EventBusTests(unittest.TestCase):
    def test_emit_and_subscribe(self):
        bus = EventBus()
        received = []

        def handler(event):
            received.append(event)

        bus.subscribe("test.event", handler)
        bus.emit_simple("test.event", "src", "Title", "Message", {"key": "value"})

        self.assertEqual(len(received), 1)
        self.assertEqual(received[0].event_type, "test.event")
        self.assertEqual(received[0].severity, "info")
        self.assertEqual(received[0].actions, [])

    def test_event_with_severity_and_actions(self):
        bus = EventBus()
        received = []

        def handler(event):
            received.append(event)

        bus.subscribe("build.failed", handler)
        event = Event(
            event_type="build.failed",
            timestamp=0.0,
            source="vscode",
            title="Build Failed",
            message="collector.py:182",
            data={},
            severity="error",
            actions=["open.error", "rebuild"],
        )
        bus.emit(event)

        self.assertEqual(received[0].severity, "error")
        self.assertEqual(received[0].actions, ["open.error", "rebuild"])

    def test_last_event(self):
        bus = EventBus()
        bus.emit_simple("git.changed", "git", "Git", "Changed")
        last = bus.last_event("git.changed")
        self.assertIsNotNone(last)
        self.assertEqual(last.title, "Git")


class SystemIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.integration = SystemIntegration()

    def test_open_project_validates_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.integration.open_project(tmp)
            self.assertIn("opened", result)

    def test_open_project_rejects_file(self):
        with tempfile.NamedTemporaryFile() as tmp:
            result = self.integration.open_project(tmp.name)
            self.assertFalse(result.get("ok", True))


class ActionRegistrySystemTests(unittest.TestCase):
    def test_registry_contains_new_actions(self):
        registry = ActionRegistry()
        self.assertEqual(set(registry._registry.keys()), {
            "system.open_url",
            "system.volume_up",
            "system.volume_down",
            "system.mute",
            "system.lock_screen",
            "system.screenshot",
            "system.open_terminal",
            "system.open_project",
            "system.set_workspace",
            "system.volume",
            "system.battery",
            "vscode.open_workspace",
            "vscode.status",
            "vscode.workspaces",
            "git.status",
            "git.branches",
            "git.tree",
            "git.log",
            "git.add",
            "git.switch_branch",
            "git.pull",
            "git.push",
            "git.commit",
            "media.status",
            "media.play_pause",
            "media.next",
            "media.previous",
            "media.volume",
            "media.seek",
            "media.open_spotify",
            "docker.status",
            "docker.start",
            "docker.stop",
            "docker.restart",
            "docker.logs",
            "clipboard.get",
            "clipboard.set",
            "clipboard.status",
            "clipboard.clear_history",
            "context.status",
            "context.override",
            "context.clear_override",
            "context.surfaces",
            "context.surface",
            "vscode.run_task",
            "vscode.debug",
            "vscode.test",
            "vscode.open_file",
            "system.apps",
            "system.open_app",
            "system.focus_app",
            "system.brightness",
            "system.sinks",
            "system.set_sink",
            "chrome.back",
            "chrome.forward",
            "chrome.refresh",
            "chrome.new_tab",
            "chrome.close_tab",
            "chrome.reopen_tab",
            "chrome.copy_url",
            "chrome.devtools",
            "teams.mute",
            "teams.camera",
            "teams.share",
            "teams.leave",
            "window.list",
            "window.focus",
            "window.move",
            "window.minimize",
            "window.maximize",
            "window.close",
            "window.layouts",
            "window.apply_layout",
            "project.open",
            "project.resources",
            "terminal.clear",
            "terminal.rerun",
            "terminal.kill",
            "system.sources",
            "system.set_source",
        })

    def test_unknown_action_returns_error(self):
        registry = ActionRegistry()
        result = registry.execute("unknown.action", {})
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "unknown_action")


if __name__ == "__main__":
    unittest.main()
