# Integrations

Every capability in Tact is a **self-contained integration folder** — one
folder per app, with its own files. This makes adding features (e.g.
"figma support", "video editing support") and fixing bugs a matter of
touching only that app's folder.

## Layout

```
tact/agent/integrations/
├── base.py            <- Integration base class (the contract)
├── git/               <- GitIntegration
│   ├── __init__.py    <- re-exports GitIntegration
│   ├── integration.py <- the integration class (actions, snapshot, monitor)
│   └── state.py       <- GitStatus domain type
├── vscode/
│   ├── __init__.py
│   └── integration.py
├── system/
│   ├── __init__.py
│   └── integration.py <- platform-aware system actions (volume, lock, …)
├── media/
│   ├── __init__.py
│   └── integration.py <- playerctl + xdotool media-key fallback
├── docker/
│   ├── __init__.py
│   └── integration.py <- containers, lifecycle, logs
├── clipboard/
│   ├── __init__.py
│   └── integration.py <- read/write/history
└── context/           <- Phase 2 Context Engine
    ├── __init__.py
    ├── integration.py <- the ContextIntegration
    ├── apps.py        <- WM_CLASS -> app id -> workflow maps
    └── detection.py   <- X11 active-window detection (swap for Wayland here)
```

An integration owns four things (see `base.py`):

| Member      | Purpose                                                              |
| ----------- | -------------------------------------------------------------------- |
| `name`      | Stable id; becomes the action prefix (`<name>.<action>`) and the snapshot key |
| `actions()` | `dict` of action-suffix -> handler. Handlers take the payload `dict` from the phone and return a plain `dict` |
| `snapshot()`| Contribution to the state snapshot pushed to the phone every 5s      |
| `monitor()` | Optional; called every 10s by `StateMonitor`; emit events via the `EventBus` (e.g. `git.state_changed`) |

Helper files (like `git/state.py`, `context/apps.py`) are just regular
modules inside the folder — split however the app's code reads best.

## How a request flows

```
Phone app
  └─ action "git.pull" ── WebSocket ──> main.py
                                         └─ ActionRegistry.execute()        (actions.py)
                                             └─ registry["git.pull"]        (registered by GitIntegration.actions())
                                                 └─ GitIntegration.pull()   (integrations/git/integration.py)
```

`ActionRegistry` (`actions.py`) collects each integration's `actions()`
and keys them as `<name>.<suffix>`. Registration is **explicit**: each
integration is imported and instantiated in `ActionRegistry.__init__` —
one import + one line in the `integrations` list. The only other
handlers in `actions.py` are *composites* — actions spanning two
integrations (`system.set_workspace`, `media.open_spotify`).

Snapshot composition (`main.py` → `snapshot_state`) iterates
`integrations` and calls `snapshot()` on each; the `workspace` block is
the one cross-integration view and is assembled explicitly.

## Adding a new capability (e.g. "figma support")

1. Create `tact/agent/integrations/figma/` with:

   ```python
   # integrations/figma/integration.py
   from ..base import Integration

   class FigmaIntegration(Integration):
       name = "figma"

       def actions(self):
           return {
               "status": lambda p: self.status(),
               "open_file": lambda p: self.open_file(p.get("file_id")),
           }

       def snapshot(self):
           return self.status()

       def monitor(self, event_bus):
           ...  # optional: emit figma.state_changed
   ```

   ```python
   # integrations/figma/__init__.py
   from .integration import FigmaIntegration
   ```

   Add any helper files the app needs (`state.py`, `api.py`, …) beside them.

2. Register it in `ActionRegistry.__init__` (`actions.py`):

   ```python
   from .integrations.figma import FigmaIntegration
   ...
   self.figma = FigmaIntegration()
   self.integrations = [..., self.figma]
   ```

   The action `figma.status` is now callable and the snapshot carries a
   `figma` key. Nothing in `main.py` or `monitoring.py` changes.

3. (Optional) add a platform-native view under the relevant `native/` project.

## State change events

Integrations that want to push events implement `monitor()` and emit
`<name>.state_changed` via the event bus. `main.py` subscribes the
WebSocket to those events (currently: git, vscode, docker, context).

## Platform notes

* `system/` is the platform router (linux/darwin/win32).
* `media/` falls back to X11 media keys (xdotool) because snap
  Spotify's MPRIS registration comes and goes.
* `context/detection.py` uses X11 `xprop`/`xdotool`; Wayland/headless
  degrade gracefully (`available: False`). A Wayland backend slots in
  by replacing that one file.
* Everything else (git, docker, clipboard, vscode) is already
  cross-platform by design.
