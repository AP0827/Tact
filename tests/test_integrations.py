from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from tact.agent.integrations.git import GitIntegration
from tact.agent.integrations.vscode import VSCodeIntegration
from tact.agent.integrations.media import MediaIntegration
from tact.agent.integrations.docker import DockerIntegration
from tact.agent.integrations.clipboard import ClipboardIntegration
from tact.agent.integrations.context import ContextIntegration
from tact.agent.integrations.chrome import ChromeIntegration
from tact.agent.integrations.teams import TeamsIntegration
from tact.agent.integrations.window import WindowIntegration
from tact.agent.integrations.system import SystemIntegration
from tact.agent.integrations.project import ProjectIntegration
from tact.agent.integrations.terminal import TerminalIntegration


class GitIntegrationTests(unittest.TestCase):
    def test_discover_root_finds_git_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / ".git").mkdir()
            nested = root / "sub" / "dir"
            nested.mkdir(parents=True)

            integration = GitIntegration()
            discovered = integration.discover_root(nested)

            self.assertEqual(discovered, root)

    @patch("tact.agent.integrations.git.integration.subprocess.run")
    @patch("tact.agent.integrations.git.integration.shutil_which", return_value="git")
    def test_status_uses_git_commands(self, mock_which, mock_run):
        def run_side_effect(cmd, capture_output, text, check):
            command = cmd[3:]

            class Result:
                def __init__(self, returncode=0, stdout="", stderr=""):
                    self.returncode = returncode
                    self.stdout = stdout
                    self.stderr = stderr

            if command[:2] == ["status", "--porcelain=v1"]:
                return Result(stdout=" M file.txt\n")
            if command[:2] == ["branch", "--show-current"]:
                return Result(stdout="main\n")
            if command[:3] == ["rev-parse", "--short", "HEAD"]:
                return Result(stdout="abc123\n")
            if command[:3] == ["rev-parse", "--abbrev-ref", "--symbolic-full-name"]:
                return Result(returncode=1)
            return Result()

        mock_run.side_effect = run_side_effect

        integration = GitIntegration()
        with patch.object(GitIntegration, "discover_root", return_value=Path("/repo")):
            status = integration.status("/repo")

        self.assertTrue(status["available"])
        self.assertEqual(status["branch"], "main")
        self.assertEqual(status["commit"], "abc123")
        self.assertEqual(status["changed_files"], 1)
        self.assertFalse(status["clean"])

    @patch("tact.agent.integrations.git.integration.subprocess.run")
    @patch("tact.agent.integrations.git.integration.shutil_which", return_value="git")
    def test_branches_lists_branches(self, mock_which, mock_run):
        def run_side_effect(cmd, capture_output, text, check):
            class Result:
                def __init__(self, returncode=0, stdout="", stderr=""):
                    self.returncode = returncode
                    self.stdout = stdout
                    self.stderr = stderr

            if cmd[3:] == ["branch", "--show-current"]:
                return Result(stdout="main\n")
            if cmd[3:] == ["branch", "-a"]:
                return Result(stdout="  main\n* dev\n  remotes/origin/feature\n")
            return Result()

        mock_run.side_effect = run_side_effect

        integration = GitIntegration()
        with patch.object(GitIntegration, "discover_root", return_value=Path("/repo")):
            branches = integration.branches("/repo")

        self.assertTrue(branches["available"])
        self.assertEqual(branches["current"], "main")
        self.assertIn("main", branches["branches"])
        self.assertIn("dev", branches["branches"])
        self.assertIn("remotes/origin/feature", branches["branches"])

    @patch("tact.agent.integrations.git.integration.subprocess.run")
    @patch("tact.agent.integrations.git.integration.shutil_which", return_value="git")
    def test_tree_returns_file_list(self, mock_which, mock_run):
        def run_side_effect(cmd, capture_output, text, check):
            class Result:
                def __init__(self, returncode=0, stdout="", stderr=""):
                    self.returncode = returncode
                    self.stdout = stdout
                    self.stderr = stderr

            if cmd[3:] == ["ls-tree", "-r", "--name-only", "-z", "HEAD"]:
                return Result(stdout="README.md\0src/main.py\0src/utils/helper.py\0")
            return Result()

        mock_run.side_effect = run_side_effect

        integration = GitIntegration()
        with patch.object(GitIntegration, "discover_root", return_value=Path("/repo")):
            tree = integration.tree("/repo")

        self.assertTrue(tree["available"])
        self.assertEqual(tree["file_count"], 3)

        def collect_names(nodes):
            names = []
            for node in nodes:
                names.append(node["name"])
                if node.get("children"):
                    names.extend(collect_names(node["children"]))
            return names

        names = collect_names(tree["tree"])
        self.assertIn("README.md", names)
        self.assertIn("main.py", names)
        self.assertIn("helper.py", names)


class VSCodeIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.vscode.integration.subprocess.Popen")
    @patch.object(VSCodeIntegration, "resolve_command", return_value="code")
    def test_open_workspace_returns_ok(self, mock_resolve, mock_popen):
        integration = VSCodeIntegration()
        result = integration.open_workspace("/tmp/project")

        self.assertTrue(result["ok"])
        self.assertEqual(result["command"], "code")
        mock_popen.assert_called_once()

    def test_workspaces_detects_open_folders(self):
        import sys
        import types
        from pathlib import Path

        mock_psutil = types.ModuleType("psutil")
        mock_proc = type("Proc", (), {
            "info": {
                "name": "code",
                "cmdline": ["code", "/home/user/project"],
            }
        })()
        mock_psutil.process_iter = lambda *args, **kwargs: [mock_proc]
        mock_psutil.NoSuchProcess = Exception
        mock_psutil.AccessDenied = Exception

        sys.modules["psutil"] = mock_psutil
        try:
            with tempfile.TemporaryDirectory() as tmp:
                project_dir = Path(tmp) / "project"
                project_dir.mkdir()
                mock_proc.info["cmdline"] = ["code", str(project_dir)]

                integration = VSCodeIntegration(config_dir=Path(tmp) / "config")
                integration._which = lambda cmd: cmd == "code" and "/usr/bin/code"

                with patch.object(Path, "is_dir", return_value=True):
                    result = integration.workspaces()

                self.assertTrue(result["available"])
                self.assertEqual(result["count"], 1)
                self.assertIn(str(project_dir), result["workspaces"])
        finally:
            del sys.modules["psutil"]


class MediaIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/playerctl")
    @patch("tact.agent.integrations.media.integration.subprocess.run")
    def test_status_reports_unavailable_when_players_missing(self, mock_run, mock_which):
        class Result:
            def __init__(self, returncode=0, stdout=""):
                self.returncode = returncode
                self.stdout = stdout

        mock_run.return_value = Result()
        integration = MediaIntegration()
        self.assertTrue(integration.is_available())
        status = integration.status()
        self.assertTrue(status["available"])
        self.assertEqual(status["players"], [])
        self.assertIsNone(status["active"])
        self.assertNotIn("hint", status)

    @patch("tact.agent.integrations.media.integration.shutil.which", return_value=None)
    def test_status_reports_not_installed(self, mock_which):
        integration = MediaIntegration()
        self.assertFalse(integration.is_available())
        status = integration.status()
        self.assertFalse(status["available"])
        self.assertIn("error", status)

    @patch("tact.agent.integrations.media.integration.os.environ", {})
    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/spotify")
    def test_open_spotify_launches_app(self, mock_which, mock_popen):
        integration = MediaIntegration()
        result = integration.open_spotify()
        self.assertTrue(result["ok"])
        self.assertEqual(result["method"], "app")
        launch_call = mock_popen.call_args_list[0]
        self.assertEqual(launch_call[0][0], ["/usr/bin/spotify"])
        mock_popen.assert_called()

    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value=None)
    def test_open_spotify_falls_back_when_not_installed(self, mock_which, mock_popen):
        integration = MediaIntegration()
        result = integration.open_spotify()
        self.assertFalse(result["ok"])
        self.assertEqual(result["method"], "app_not_found")
        self.assertIn("fallback", result)

    @patch("tact.agent.integrations.media.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/xdotool")
    def test_play_pause_falls_back_to_media_key(self, mock_which, mock_popen):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        # playerctl fails (player not registered) -> xdotool fallback.
        def run_side_effect(cmd, **kwargs):
            return Result(returncode=1)

        integration = MediaIntegration()
        with patch("tact.agent.integrations.media.integration.subprocess.run", side_effect=run_side_effect):
            result = integration.play_pause()

        self.assertTrue(result["ok"])
        self.assertEqual(result["method"], "xdotool")
        self.assertEqual(result["key"], "XF86AudioPlay")
        args = mock_popen.call_args[0][0]
        self.assertIn("XF86AudioPlay", args)

    @patch("tact.agent.integrations.media.integration.subprocess.Popen")
    @patch("tact.agent.integrations.media.integration.shutil.which", return_value="/usr/bin/playerctl")
    def test_play_pause_uses_playerctl_when_available(self, mock_which, mock_popen):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        integration = MediaIntegration()
        with patch("tact.agent.integrations.media.integration.subprocess.run", return_value=Result(returncode=0)):
            result = integration.play_pause("spotify")

        self.assertTrue(result["ok"])
        self.assertEqual(result["method"], "playerctl")
        self.assertEqual(result["player"], "spotify")


class DockerIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_containers_parses_output(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "api\trunning\tpostgres:15\tUp 2 hours\nredis\texited\tredis:7\tExited (0) 5 minutes ago\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = DockerIntegration()
        result = integration.containers()

        self.assertTrue(result["available"])
        self.assertEqual(result["count"], 2)
        self.assertEqual(result["containers"][0]["name"], "api")
        self.assertEqual(result["containers"][0]["state"], "running")
        self.assertEqual(result["containers"][1]["state"], "exited")

    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_permission_denied_reported(self, mock_run, mock_which):
        class Result:
            returncode = 1
            stdout = ""
            stderr = "permission denied while trying to connect to the docker daemon socket"

        mock_run.return_value = Result()
        integration = DockerIntegration()
        result = integration.containers()

        self.assertFalse(result["available"])
        self.assertEqual(result["error"], "docker_permission_denied")

    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_start_requires_name(self, mock_run, mock_which):
        integration = DockerIntegration()
        result = integration.start("")
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "container_name_required")

    @patch("tact.agent.integrations.docker.integration.shutil.which", return_value="/usr/bin/docker")
    @patch("tact.agent.integrations.docker.integration.subprocess.run")
    def test_logs_returns_output(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "line1\nline2\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = DockerIntegration()
        result = integration.logs("api", tail=10)

        self.assertTrue(result["ok"])
        self.assertEqual(result["container"], "api")
        self.assertEqual(result["logs"], "line1\nline2")
        mock_run.assert_called_once()
        self.assertIn("--tail", mock_run.call_args[0][0])


class ClipboardIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.clipboard.integration.shutil.which", return_value="/usr/bin/xsel")
    @patch("tact.agent.integrations.clipboard.integration.subprocess.run")
    def test_get_reads_clipboard(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "copied text\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = ClipboardIntegration()
        result = integration.get()

        self.assertTrue(result["ok"])
        self.assertEqual(result["text"], "copied text")
        mock_run.assert_called_once()
        self.assertIn("-o", mock_run.call_args[0][0])

    @patch("tact.agent.integrations.clipboard.integration.shutil.which", return_value="/usr/bin/xsel")
    @patch("tact.agent.integrations.clipboard.integration.subprocess.run")
    def test_set_writes_and_records_history(self, mock_run, mock_which):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        clipboard: dict[str, str] = {"value": ""}

        def run_side_effect(cmd, **kwargs):
            # Read path returns whatever was "written" (the mock clipboard).
            if "-i" in cmd:
                clipboard["value"] = kwargs.get("input") or ""
            return Result(stdout=clipboard["value"])

        mock_run.side_effect = run_side_effect
        integration = ClipboardIntegration()
        result = integration.set("hello from phone")

        self.assertTrue(result["ok"])
        self.assertEqual(result["written"], 16)
        self.assertEqual(integration._history, ["hello from phone"])

        status = integration.status()
        self.assertEqual(status["history"], ["hello from phone"])
        self.assertEqual(status["text"], "hello from phone")

    @patch("tact.agent.integrations.clipboard.integration.shutil.which", return_value=None)
    def test_unavailable_when_no_tool(self, mock_which):
        integration = ClipboardIntegration()
        self.assertFalse(integration.is_available())
        self.assertFalse(integration.get()["ok"])
        self.assertFalse(integration.set("x")["ok"])

    def test_history_deduplicates_and_limits(self):
        integration = ClipboardIntegration(history_size=3)
        for text in ["a", "b", "c", "a", "d"]:
            integration.set(text)
        self.assertEqual(integration._history, ["d", "a", "c"])

    @patch("tact.agent.integrations.clipboard.integration.shutil.which", side_effect=lambda cmd: "/usr/bin/xclip" if cmd == "xclip" else None)
    @patch("tact.agent.integrations.clipboard.integration.subprocess.run")
    def test_image_support_detection(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "TARGETS\nUTF8_STRING\nimage/png\n"
            stderr = ""

        mock_run.return_value = Result()
        integration = ClipboardIntegration()
        caps = integration.capabilities()

        self.assertTrue(caps["image"])
        self.assertEqual(caps["backend"], "xclip")


class ContextIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.context.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.context.detection.subprocess.run")
    def test_detect_maps_active_window_to_app(self, mock_run):
        class Result:
            def __init__(self, returncode=0, stdout="", stderr=""):
                self.returncode = returncode
                self.stdout = stdout
                self.stderr = stderr

        calls = {
            "xprop": [
                Result(stdout="window id # 0x3600004\n"),
                Result(
                    stdout='_NET_WM_NAME(UTF8_STRING) = "main.dart — Tact"\n'
                           'WM_CLASS(STRING) = "code", "Code"\n'
                ),
            ],
        }

        def run_side_effect(cmd, **kwargs):
            if cmd[0] == "xprop":
                return calls["xprop"].pop(0)
            # git commands during branch resolution -> no repo context
            return Result()

        mock_run.side_effect = run_side_effect

        integration = ContextIntegration()
        with patch.object(integration._git, "discover_root", return_value=None):
            result = integration.detect()

        self.assertTrue(result["available"])
        self.assertEqual(result["active_app"], "vscode")
        self.assertEqual(result["active_app_raw"], "code")
        self.assertEqual(result["workflow"], "development")

    @patch("tact.agent.integrations.context.detection.os.environ", {})
    def test_detect_unavailable_without_display(self):
        integration = ContextIntegration()
        result = integration.detect()

        self.assertFalse(result["available"])
        self.assertIn("error", result)

    def test_override_and_clear(self):
        integration = ContextIntegration()
        result = integration.set_override("figma", "/home/user/design")
        self.assertTrue(result["ok"])
        self.assertEqual(integration._override["app"], "figma")

        detected = integration.detect()
        self.assertEqual(detected["active_app"], "figma")
        self.assertEqual(detected["project"], "/home/user/design")
        self.assertEqual(detected["workflow"], "design")

        result = integration.clear_override()
        self.assertTrue(result["ok"])
        self.assertIsNone(result["override"])

    def test_path_from_terminal_title(self):
        with tempfile.TemporaryDirectory() as tmp:
            proj = Path(tmp) / "Tact"
            proj.mkdir()
            integration = ContextIntegration()
            path = integration._path_from_title(f"user@host: {proj} — konsole")
            self.assertEqual(path, str(proj))

    def test_terminal_title_ignores_missing_path(self):
        integration = ContextIntegration()
        path = integration._path_from_title("user@host: ~/does/not/exist")
        self.assertIsNone(path)

    def test_workflow_classification(self):
        from tact.agent.integrations.context.apps import classify

        self.assertEqual(classify("vscode"), "development")
        self.assertEqual(classify("teams"), "meeting")
        self.assertEqual(classify("spotify"), "media")
        self.assertIsNone(classify("unknown-app"))

    def test_monitor_emits_context_changed_on_change(self):
        from tact.agent.events import EventBus

        integration = ContextIntegration()
        window = {"id": "0x1", "class": "code", "title": "main.dart — Tact"}
        with patch("tact.agent.integrations.context.integration.active_window", return_value=window):
            integration.workspace_path = "/home/user/Tact"

            bus = EventBus()
            received = []
            bus.subscribe("context.changed", lambda e: received.append(e))

            integration.monitor(bus)  # first check: no event (baseline)
            self.assertEqual(len(received), 0)

            window["class"] = "spotify"
            window["title"] = "Spotify"
            integration.monitor(bus)  # changed -> event
            self.assertEqual(len(received), 1)
            self.assertEqual(received[0].event_type, "context.changed")
            self.assertEqual(received[0].data["active_app"], "spotify")

            integration.monitor(bus)  # unchanged -> no event
            self.assertEqual(len(received), 1)

    # -- Phase 2: signal aggregation --------------------------------------

    class _FakeDocker:
        def __init__(self, running: bool):
            self._running = running

        def containers(self) -> dict:
            if not self._running:
                return {"available": True, "containers": [], "count": 0}
            return {
                "available": True,
                "containers": [{"name": "postgres", "state": "running"}],
                "count": 1,
            }

    @patch("tact.agent.integrations.context.integration.active_window")
    def test_unknown_app_with_running_docker_classifies_development(self, mock_window):
        mock_window.return_value = {"id": "0x1", "class": "some-unknown-app", "title": ""}
        integration = ContextIntegration()
        integration._docker = self._FakeDocker(running=True)

        result = integration.detect()

        self.assertEqual(result["workflow"], "development")
        self.assertTrue(result["signals"]["docker_running"])
        self.assertFalse(result["signals"]["git_active"])

    @patch("tact.agent.integrations.context.integration.active_window")
    def test_unknown_app_without_signals_has_no_workflow(self, mock_window):
        mock_window.return_value = {"id": "0x1", "class": "some-unknown-app", "title": ""}
        integration = ContextIntegration()
        integration._docker = self._FakeDocker(running=False)

        result = integration.detect()

        self.assertIsNone(result["workflow"])
        self.assertFalse(result["signals"]["docker_running"])

    @patch("tact.agent.integrations.context.integration.active_window")
    def test_active_git_project_classifies_development(self, mock_window):
        mock_window.return_value = {"id": "0x1", "class": "some-unknown-app", "title": ""}
        integration = ContextIntegration()
        integration.workspace_path = "/repo"
        with patch.object(
            integration._git, "discover_root", return_value="/repo"
        ), patch.object(
            integration._git,
            "status",
            return_value={"available": True, "branch": "main", "clean": False},
        ):
            result = integration.detect()

        self.assertEqual(result["workflow"], "development")
        self.assertTrue(result["signals"]["git_active"])

    @patch("tact.agent.integrations.context.integration.active_window")
    def test_known_app_workflow_wins_over_signals(self, mock_window):
        mock_window.return_value = {"id": "0x1", "class": "teams", "title": "Meeting"}
        integration = ContextIntegration()
        integration._docker = self._FakeDocker(running=True)

        result = integration.detect()

        self.assertEqual(result["workflow"], "meeting")

    # -- Phase 3.1: surface selection --------------------------------------

    @patch("tact.agent.integrations.context.integration.active_window")
    def test_surface_selected_for_known_app(self, mock_window):
        mock_window.return_value = {"id": "0x1", "class": "code", "title": "main.dart — Tact"}
        integration = ContextIntegration()
        with patch.object(integration._git, "discover_root", return_value=None):
            result = integration.detect()

        self.assertEqual(result["surface"]["id"], "vscode")
        self.assertEqual(result["surface"]["title"], "VS Code")
        self.assertEqual(result["surface"]["state_card"], "git")
        self.assertTrue(
            any(a["id"] == "git.pull" for a in result["surface"]["actions"])
        )
        self.assertIn("surfaces", result)
        self.assertTrue(any(s["id"] == "fallback" for s in result["surfaces"]))

    @patch("tact.agent.integrations.context.integration.active_window")
    def test_surface_fallback_for_unknown_app(self, mock_window):
        mock_window.return_value = {"id": "0x1", "class": "weird-app", "title": ""}
        integration = ContextIntegration()

        result = integration.detect()

        self.assertEqual(result["surface"]["id"], "fallback")
        self.assertEqual(result["surface"]["title"], "Desktop")

    @patch("tact.agent.integrations.context.detection.os.environ", {})
    def test_surface_fallback_when_detection_unavailable(self):
        integration = ContextIntegration()
        result = integration.detect()

        self.assertFalse(result["available"])
        self.assertEqual(result["surface"]["id"], "fallback")

    def test_surfaces_action_lists_registry(self):
        integration = ContextIntegration()
        result = integration.surfaces()

        self.assertTrue(result["ok"])
        ids = {s["id"] for s in result["surfaces"]}
        self.assertTrue({"vscode", "terminal", "spotify", "fallback"} <= ids)

    def test_spotify_surface_media_state_card(self):
        from tact.agent.integrations.context.surfaces import SURFACES

        spotify = SURFACES["spotify"].to_json()
        self.assertEqual(spotify["state_card"], "media")
        self.assertEqual(
            [a["id"] for a in spotify["actions"]],
            ["media.play_pause", "media.previous", "media.next"],
        )

    def test_browser_surfaces_prompt_for_url(self):
        from tact.agent.integrations.context.surfaces import SURFACES

        chrome = SURFACES["chrome"].to_json()
        url_action = next(a for a in chrome["actions"] if a["id"] == "system.open_url")
        self.assertEqual(url_action["prompt"], "url")


class ChromeIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.chrome.integration.shutil.which", return_value="/usr/bin/xdotool")
    @patch("tact.agent.integrations.chrome.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.chrome.integration.subprocess.run")
    def test_back_sends_alt_left(self, mock_run, mock_which):
        integration = ChromeIntegration()
        result = integration.actions()["back"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(result["key"], "alt+Left")
        mock_run.assert_called_once()
        self.assertEqual(mock_run.call_args[0][0], ["xdotool", "key", "--clearmodifiers", "alt+Left"])

    @patch("tact.agent.integrations.chrome.integration.shutil.which", return_value="/usr/bin/xdotool")
    @patch("tact.agent.integrations.chrome.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.chrome.integration.subprocess.run")
    def test_copy_url_sends_two_keys(self, mock_run, mock_which):
        integration = ChromeIntegration()
        result = integration.actions()["copy_url"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(len(mock_run.call_args_list), 2)
        self.assertEqual(mock_run.call_args_list[1][0][0][3], "ctrl+c")

    @patch("tact.agent.integrations.chrome.integration.shutil.which", return_value=None)
    def test_unavailable_without_xdotool(self, mock_which):
        integration = ChromeIntegration()
        result = integration.actions()["refresh"]({})
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "xdotool_unavailable")


class TeamsIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.teams.integration.shutil.which", side_effect=lambda p: "/usr/bin/" + p)
    @patch("tact.agent.integrations.teams.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.teams.integration.subprocess.run")
    def test_mute_focuses_teams_then_keys(self, mock_run, mock_which):
        integration = TeamsIntegration()
        result = integration.actions()["mute"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(result["key"], "ctrl+shift+m")
        calls = mock_run.call_args_list
        self.assertEqual(calls[0][0][0], ["wmctrl", "-a", "Teams"])
        self.assertEqual(calls[1][0][0], ["xdotool", "key", "--clearmodifiers", "ctrl+shift+m"])

    @patch("tact.agent.integrations.teams.integration.shutil.which", return_value=None)
    def test_unavailable_without_tools(self, mock_which):
        integration = TeamsIntegration()
        result = integration.actions()["leave"]({})
        self.assertFalse(result["ok"])


class WindowIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.window.integration.shutil.which", return_value="/usr/bin/wmctrl")
    @patch("tact.agent.integrations.window.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.window.integration.subprocess.run")
    def test_list_parses_wmctrl_output(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = (
                "0x04000007  0 host Tact — Visual Studio Code   code.Code\n"
                "0x05000003  1 host Konsole   org.kde.konsole.Konsole\n"
            )

        mock_run.return_value = Result()
        integration = WindowIntegration()
        result = integration.actions()["list"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(len(result["windows"]), 2)
        self.assertEqual(result["windows"][0]["wm_class"], "code.Code")
        self.assertEqual(result["windows"][1]["desktop"], 1)

    @patch("tact.agent.integrations.window.integration.shutil.which", return_value="/usr/bin/wmctrl")
    @patch("tact.agent.integrations.window.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.window.integration.subprocess.run")
    def test_maximize_sets_property(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = ""

        mock_run.return_value = Result()
        integration = WindowIntegration()
        result = integration.actions()["maximize"]({"title": "Konsole"})
        self.assertTrue(result["ok"])
        self.assertEqual(
            mock_run.call_args[0][0],
            ["wmctrl", "-r", "Konsole", "-b", "add,maximized_vert,maximized_horz"],
        )

    @patch("tact.agent.integrations.window.integration.shutil.which", return_value="/usr/bin/wmctrl")
    @patch("tact.agent.integrations.window.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.window.integration.subprocess.run")
    def test_apply_layout_reports_missing_windows(self, mock_run, mock_which):
        class Result:
            returncode = 1
            stdout = ""

        mock_run.return_value = Result()
        integration = WindowIntegration()
        result = integration.actions()["apply_layout"]({"name": "coding"})
        self.assertTrue(result["ok"])
        self.assertEqual(result["layout"], "coding")
        self.assertGreaterEqual(len(result["missing"]), 3)

    def test_apply_layout_rejects_unknown(self):
        integration = WindowIntegration()
        result = integration.actions()["apply_layout"]({"name": "bogus"})
        self.assertFalse(result["ok"])

    def test_layouts_lists_presets(self):
        integration = WindowIntegration()
        result = integration.actions()["layouts"]({})
        self.assertTrue(result["ok"])
        names = {l["name"] for l in result["layouts"]}
        self.assertTrue({"coding", "meeting", "media"} <= names)


class SystemAppLauncherTests(unittest.TestCase):
    def setUp(self):
        self.integration = SystemIntegration()

    @patch("tact.agent.integrations.system.integration.shutil.which", return_value="/usr/bin/wmctrl")
    @patch("tact.agent.integrations.system.integration.subprocess.run")
    def test_apps_marks_running_from_wmctrl(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "0x04000007  0 host Tact — Visual Studio Code   code.Code\n"

        mock_run.return_value = Result()
        result = self.integration.actions()["apps"]({})
        self.assertTrue(result["ok"])
        by_id = {a["id"]: a for a in result["apps"]}
        self.assertTrue(by_id["vscode"]["running"])
        self.assertFalse(by_id["chrome"]["running"])
        self.assertIn("development", result["groups"])

    @patch("tact.agent.integrations.system.integration.subprocess.Popen")
    @patch("tact.agent.integrations.system.integration.shutil.which", side_effect=lambda p: "/usr/bin/" + p if p == "code" else None)
    def test_open_app_launches_and_focuses(self, mock_which, mock_popen):
        result = self.integration.actions()["open_app"]({"app": "vscode"})
        self.assertTrue(result["ok"])
        launch_call = mock_popen.call_args_list[0]
        self.assertEqual(launch_call[0][0], ["code"])

    def test_open_app_rejects_unknown(self):
        result = self.integration.actions()["open_app"]({"app": "nope"})
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "unknown_app")

    def test_open_app_requires_app(self):
        result = self.integration.actions()["open_app"]({})
        self.assertFalse(result["ok"])

    @patch("tact.agent.integrations.system.integration.shutil.which", return_value=None)
    def test_apps_graceful_without_wmctrl(self, mock_which):
        result = self.integration.actions()["apps"]({})
        self.assertTrue(result["ok"])
        self.assertTrue(result["apps"])
        self.assertTrue(all(not a["running"] for a in result["apps"]))

    @patch("tact.agent.integrations.system.integration.shutil.which", return_value="/usr/bin/pactl")
    @patch("tact.agent.integrations.system.integration.subprocess.run")
    def test_sinks_marks_default(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = "analog\n"

        mock_run.return_value = Result()
        mock_run.side_effect = [
            Result(),  # get-default-sink -> "analog"
            SimpleNamespace(returncode=0, stdout="0\thdmi\n1\tanalog\n"),
        ]
        result = self.integration.actions()["sinks"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(result["default"], "analog")
        by_name = {s["name"]: s for s in result["sinks"]}
        self.assertTrue(by_name["analog"]["default"])
        self.assertFalse(by_name["hdmi"]["default"])

    @patch("tact.agent.integrations.system.integration.shutil.which", return_value="/usr/bin/pactl")
    @patch("tact.agent.integrations.system.integration.subprocess.run")
    def test_set_sink_calls_pactl(self, mock_run, mock_which):
        class Result:
            returncode = 0
            stdout = ""

        mock_run.return_value = Result()
        result = self.integration.actions()["set_sink"]({"sink": "hdmi"})
        self.assertTrue(result["ok"])
        self.assertEqual(mock_run.call_args[0][0], ["pactl", "set-default-sink", "hdmi"])

    @patch("tact.agent.integrations.system.integration.shutil.which", return_value="/usr/bin/xrandr")
    @patch("tact.agent.integrations.system.integration.subprocess.run")
    def test_brightness_sets_overlay(self, mock_run, mock_which):
        class Result:
            def __init__(self, stdout="", returncode=0):
                self.stdout = stdout
                self.returncode = returncode

        mock_run.side_effect = [
            Result("eDP-1 connected primary 1920x1080\nHDMI-1 disconnected\n"),
            Result(),
        ]
        result = self.integration.actions()["brightness"]({"value": "50"})
        self.assertTrue(result["ok"])
        self.assertEqual(result["brightness"], 50)
        self.assertEqual(
            mock_run.call_args_list[1][0][0],
            ["xrandr", "--output", "eDP-1", "--brightness", "0.50"],
        )


class ProjectIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.project.integration.shutil.which", return_value="/usr/bin/code")
    @patch("tact.agent.integrations.project.integration.subprocess.Popen")
    @patch("tact.agent.integrations.project.integration.Path.is_dir", return_value=True)
    def test_open_launches_environment(self, mock_is_dir, mock_popen, mock_which):
        integration = ProjectIntegration()
        result = integration.actions()["open"]({"path": "/home/u/Projects/Tact"})
        self.assertTrue(result["ok"])
        self.assertTrue(result["opened"]["vscode"])
        launch_call = mock_popen.call_args_list[0]
        self.assertEqual(launch_call[0][0][0], "code")

    @patch("tact.agent.integrations.project.integration.Path.is_dir", return_value=False)
    def test_open_rejects_missing_dir(self, mock_is_dir):
        integration = ProjectIntegration()
        result = integration.actions()["open"]({"path": "/nope"})
        self.assertFalse(result["ok"])

    @patch("tact.agent.integrations.project.integration.subprocess.run")
    def test_resources_includes_repo_url(self, mock_run):
        class Result:
            returncode = 0
            stdout = "git@github.com:user/repo.git\n"

        mock_run.return_value = Result()
        integration = ProjectIntegration()
        result = integration.actions()["resources"]({"path": "/home/u/Projects/Tact"})
        self.assertTrue(result["ok"])
        repo = next(r for r in result["resources"] if r["id"] == "repo")
        self.assertEqual(repo["url"], "https://github.com/user/repo")


class TerminalIntegrationTests(unittest.TestCase):
    @patch("tact.agent.integrations.terminal.integration.shutil.which", return_value="/usr/bin/xdotool")
    @patch("tact.agent.integrations.terminal.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.terminal.integration.subprocess.run")
    def test_clear_sends_ctrl_l(self, mock_run, mock_which):
        integration = TerminalIntegration()
        result = integration.actions()["clear"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(mock_run.call_args[0][0], ["xdotool", "key", "--clearmodifiers", "ctrl+l"])

    @patch("tact.agent.integrations.terminal.integration.shutil.which", return_value="/usr/bin/xdotool")
    @patch("tact.agent.integrations.terminal.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.terminal.integration.subprocess.run")
    def test_rerun_sends_up_then_return(self, mock_run, mock_which):
        integration = TerminalIntegration()
        result = integration.actions()["rerun"]({})
        self.assertTrue(result["ok"])
        keys = [call[0][0][3] for call in mock_run.call_args_list]
        self.assertEqual(keys, ["Up", "Return"])

    @patch("tact.agent.integrations.terminal.integration.shutil.which", return_value="/usr/bin/xdotool")
    @patch("tact.agent.integrations.terminal.integration.os.environ", {"DISPLAY": ":0"})
    @patch("tact.agent.integrations.terminal.integration.subprocess.run")
    def test_kill_sends_ctrl_c(self, mock_run, mock_which):
        integration = TerminalIntegration()
        result = integration.actions()["kill"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(mock_run.call_args[0][0][3], "ctrl+c")

    @patch("tact.agent.integrations.terminal.integration.shutil.which", return_value=None)
    def test_unavailable_without_xdotool(self, mock_which):
        integration = TerminalIntegration()
        result = integration.actions()["clear"]({})
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "xdotool_unavailable")


class SystemSourceSwitcherTests(unittest.TestCase):
    def setUp(self):
        self.integration = SystemIntegration()

    @patch("tact.agent.integrations.system.integration.shutil.which", return_value="/usr/bin/pactl")
    @patch("tact.agent.integrations.system.integration.subprocess.run")
    def test_sources_marks_default(self, mock_run, mock_which):
        mock_run.side_effect = [
            SimpleNamespace(returncode=0, stdout="usb_mic\n"),
            SimpleNamespace(returncode=0, stdout="0\tinternal\n1\tusb_mic\n"),
        ]
        result = self.integration.actions()["sources"]({})
        self.assertTrue(result["ok"])
        self.assertEqual(result["default"], "usb_mic")
        by_name = {s["name"]: s for s in result["sources"]}
        self.assertTrue(by_name["usb_mic"]["default"])
        self.assertFalse(by_name["internal"]["default"])

    @patch("tact.agent.integrations.system.integration.shutil.which", return_value="/usr/bin/pactl")
    @patch("tact.agent.integrations.system.integration.subprocess.run")
    def test_set_source_calls_pactl(self, mock_run, mock_which):
        mock_run.return_value = SimpleNamespace(returncode=0, stdout="")
        result = self.integration.actions()["set_source"]({"source": "internal"})
        self.assertTrue(result["ok"])
        self.assertEqual(
            mock_run.call_args[0][0], ["pactl", "set-default-source", "internal"]
        )

    def test_set_source_requires_source(self):
        result = self.integration.actions()["set_source"]({})
        self.assertFalse(result["ok"])


class TerminalSurfaceTests(unittest.TestCase):
    def test_terminal_surface_has_controls_and_card(self):
        from tact.agent.integrations.context.surfaces import SURFACES

        terminal = SURFACES["terminal"].to_json()
        self.assertEqual(terminal["state_card"], "terminal")
        ids = [a["id"] for a in terminal["actions"]]
        self.assertIn("terminal.clear", ids)
        self.assertIn("terminal.rerun", ids)
        self.assertIn("terminal.kill", ids)


class ContextRecentAppsTests(unittest.TestCase):
    @patch("tact.agent.integrations.context.integration.active_window")
    def test_recent_apps_tracks_distinct_apps(self, mock_window):
        mock_window.side_effect = [
            {"class": "code", "title": "Tact — Visual Studio Code"},
            {"class": "google-chrome", "title": "Tact - Google Chrome"},
            {"class": "code", "title": "Tact — Visual Studio Code"},
            {"class": "code", "title": "Tact — Visual Studio Code"},
        ]
        integration = ContextIntegration()
        integration.detect()
        integration.detect()
        integration.detect()
        self.assertEqual(integration.detect()["recent_apps"], ["chrome", "vscode"])


if __name__ == "__main__":
    unittest.main()

