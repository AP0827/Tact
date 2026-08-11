# Tact — Developer Productivity Control Surface

## Coding Agent Project Context & Development Brief

You are the primary coding agent responsible for developing **Tact**, a software product that turns a user's mobile device into a dynamic second interface for their computer.

You should behave as a senior software engineer and product engineer. Prioritize a clean architecture, working software, incremental development, security, maintainability, and a strong MVP over unnecessary complexity.

---

# 1. Product Context

## What is Tact?

Tact is a **developer-focused second interface for a computer**.

The user's phone acts as a programmable control surface and information panel for their laptop/desktop.

The computer runs a lightweight **Tact Desktop Agent**.

The phone connects to that agent over the local network and renders a dynamic interface.

Conceptually:

```
┌───────────────────────┐
│       COMPUTER        │
│                       │
│   Tact Desktop Agent  │
└───────────┬───────────┘
            │
      WebSocket / LAN
            │
            ▼
┌───────────────────────┐
│        PHONE          │
│                       │
│     Tact Client       │
│                       │
│ buttons / widgets     │
│ metrics / events      │
│ notifications         │
└───────────────────────┘
```

Tact is NOT intended to initially be another Stream Deck clone.

Existing products already provide customizable mobile macro/control surfaces.

The long-term product thesis is:

> **Tact is a dynamic second interface for developers: it understands what the developer is doing, displays relevant state/information, and provides contextual actions to interact with the workflow.**

The initial target user is a **software developer working from home or spending significant time at a computer**.

---

# 2. Product Vision

Tact should eventually become a developer's "cockpit" beside their laptop.

A developer might have:

* VS Code / JetBrains IDE
* Git
* GitHub/GitLab
* Docker
* terminal
* PostgreSQL
* browser
* Spotify
* Microsoft Teams / Slack / Zoom
* ChatGPT / Claude / Gemini / coding AI
* local development services

Tact should provide a persistent secondary interface containing:

### Information

* CPU/RAM/system status
* Git branch/status
* build status
* test status
* Docker container status
* CI/CD status
* notifications
* meeting state
* development events
* logs/errors

### Actions

* Run
* Build
* Test
* Git actions
* Docker actions
* Terminal actions
* Media controls
* Meeting controls
* AI actions
* Open application/file/URL
* Debug/rebuild/retry actions

The critical distinction is:

> Tact should provide both **state and control**, not merely buttons.

---

# 3. Existing Competition

The product exists in a category with products such as:

* Elgato Stream Deck Mobile
* Touch Portal
* Unified Remote
* other macro-pad / remote-control applications

Therefore, do NOT build the MVP around the assumption that "phone + buttons" is novel.

Tact's differentiation should eventually come from:

1. Developer-first workflows
2. Rich developer information
3. Context-aware interfaces
4. Event-driven notifications
5. Development-state monitoring
6. AI-generated workspaces
7. Rich widgets rather than only buttons
8. A declarative interface/action protocol
9. Extensible integrations/plugins

Do not attempt to implement all of these immediately.

---

# 4. Development Strategy

The product will be developed incrementally.

The immediate target is:

## V0.1 — Developer Control Surface

Prove that a phone can act as a useful developer control surface.

Core integrations:

* System
* VS Code
* Git
* Docker

Core capabilities:

* WebSocket communication
* dynamic UI
* buttons/actions
* system telemetry
* basic development status
* basic layouts
* persistent configuration

## V0.2 — Developer Event System

Add:

* build failure events
* test failure events
* Docker state changes
* Git state changes
* developer-focused notifications
* actionable notifications
* richer development status
* event-driven UI updates

V0.2 should make Tact feel like a **developer companion**, rather than simply a remote control.

Do NOT implement AI-generated workspaces, native mobile applications, hardware, marketplace functionality, or a large plugin ecosystem before V0.2 is stable.

---

# 5. Core Architecture

Use a three-layer architecture:

```
┌────────────────────────────────────┐
│          TACT DESKTOP AGENT        │
│                                    │
│ Context Engine                     │
│ Telemetry Engine                   │
│ Action Engine                      │
│ Event Engine                       │
│ Layout/State Manager               │
│ WebSocket Server                   │
└──────────────────┬─────────────────┘
                   │
             WebSocket / LAN
                   │
┌──────────────────▼─────────────────┐
│            TACT CLIENT              │
│                                    │
│ React + TypeScript                 │
│ Dynamic UI renderer                │
│ Event handling                     │
│ Layout rendering                   │
└────────────────────────────────────┘
```

The laptop is the **brain**.

The mobile browser is the **interface**.

---

# 6. Technology Stack

Use the following stack unless there is a strong technical reason to deviate.

## Desktop Agent

* Python
* FastAPI
* WebSockets
* Pydantic
* psutil
* subprocess / OS APIs where necessary
* SQLite or JSON for simple local persistence

## Frontend

* React
* TypeScript
* Vite
* Tailwind CSS

## Communication

Primary:

* WebSocket over local Wi-Fi/LAN

REST may be used for:

* configuration
* health checks
* initial state
* metadata
* pairing

WebSocket should handle:

* real-time state
* events
* actions
* layout changes
* notifications
* telemetry updates

Do NOT introduce Redis, Kafka, PostgreSQL, Docker, Kubernetes, cloud infrastructure, or microservices for the MVP unless there is an actual demonstrated need.

This is a local desktop application.

Keep the architecture simple.

---

# 7. Repository Structure

Prefer a structure along these lines:

```
tact/
├── agent/
│   ├── api/
│   ├── actions/
│   ├── context/
│   ├── events/
│   ├── telemetry/
│   ├── layouts/
│   ├── integrations/
│   ├── websocket/
│   ├── config/
│   └── main.py
│
├── client/
│   ├── src/
│   │   ├── components/
│   │   ├── widgets/
│   │   ├── layouts/
│   │   ├── websocket/
│   │   ├── state/
│   │   └── types/
│   └── ...
│
├── tests/
├── docs/
├── README.md
└── ...
```

You may adjust this structure if necessary, but maintain clear separation between:

* transport
* domain logic
* integrations
* UI
* configuration
* event handling

Do not create arbitrary layers merely for the sake of abstraction.

---

# 8. Most Important Architectural Principle: Declarative UI

Do NOT hardcode application-specific interfaces into React.

Avoid designs such as:

```
if application == "vscode":
    renderVSCodeButtons()
```

Instead, the desktop agent should be able to describe the interface.

For example:

```
{
  "type": "button",
  "id": "vscode.run",
  "label": "Run",
  "action": "vscode.run"
}
```

Or:

```
{
  "type": "metric",
  "id": "system.cpu",
  "label": "CPU",
  "value": 42,
  "unit": "%"
}
```

Or:

```
{
  "type": "status",
  "id": "docker.postgres",
  "label": "PostgreSQL",
  "state": "healthy"
}
```

The client renders these components.

This is a fundamental part of Tact's future architecture.

---

# 9. Initial UI Primitives

Implement a small widget system.

At minimum:

### Control widgets

* Button
* Toggle
* Slider

### Information widgets

* Metric
* Status
* Progress
* Notification
* Text

Do not build dozens of widgets.

Make these few widgets reliable and extensible.

Every widget should have:

* stable ID
* type
* display properties
* optional state
* optional action
* predictable serialization

---

# 10. Action Architecture

Do NOT allow arbitrary shell commands to be sent directly from the phone.

Never implement a generic:

```
execute arbitrary command
```

endpoint.

Instead, create an **allowlisted Action Registry**.

Example:

```
system.lock
system.volume_up
system.volume_down
system.screenshot

vscode.run
vscode.build
vscode.test

git.status
git.commit
git.push

docker.list
docker.restart
docker.logs
```

Actions should be registered by integrations.

The mobile client sends an action ID.

The desktop agent validates and executes the action.

Conceptually:

```
Phone
   │
   ▼
Action ID
   │
   ▼
Action Registry
   │
   ▼
Authorized handler
   │
   ▼
Operating system / application
```

This is important for both architecture and security.

---

# 11. V0.1 Features

Implement the following.

## 11.1 Desktop Agent

The agent should:

* start locally
* expose HTTP/WebSocket server
* determine local network address
* accept a mobile connection
* maintain connection state
* send initial application state
* receive actions
* execute registered actions
* emit events

The agent should be easy to start during development.

Example:

```
python -m tact.agent
```

Eventually this can become a packaged executable/service.

---

# 12. V0.1 Mobile Client

For V0.1, the mobile client is a **responsive web application**.

Do NOT create native Android/iOS applications yet.

The user should be able to open something like:

```
http://<laptop-ip>:<port>
```

from their phone.

The UI should be designed primarily for:

* portrait mobile screens
* touch interaction
* large controls
* readable status information

Do not optimize for desktop first.

---

# 13. V0.1 System Integration

Implement basic system information:

* CPU usage
* RAM usage
* disk usage
* battery state if available
* hostname
* OS
* uptime

Use `psutil` where possible.

The data should update periodically.

Do not stream telemetry dozens of times per second.

Use sensible intervals and only send changed/meaningful values where practical.

---

# 14. V0.1 System Actions

Implement a small safe set:

* volume up
* volume down
* mute
* lock screen
* screenshot

OS-specific behavior should be isolated behind platform abstractions.

Do not scatter Linux/Windows/macOS conditionals throughout the codebase.

Use an abstraction such as:

```
SystemController
```

with platform-specific implementations where necessary.

---

# 15. V0.1 VS Code Integration

Start with practical controls rather than trying to deeply integrate with VS Code internals.

Implement:

* open VS Code
* detect whether VS Code is active
* run/build/test where safely possible
* open terminal
* command palette if feasible
* detect active project/workspace where practical

If a capability requires OS-specific automation, isolate it behind an integration layer.

Do not build a complicated VS Code extension unless it becomes necessary.

---

# 16. V0.1 Git Integration

Tact should detect the current project/repository when possible.

Expose:

* current branch
* clean/dirty state
* number of changed files
* ahead/behind counts where available
* latest commit

Actions:

* git status
* pull
* push
* commit workflow

Do NOT implement an entire Git client.

Use Git CLI safely through a controlled integration layer.

---

# 17. V0.1 Docker Integration

If Docker is installed:

Display:

```
container name
running/stopped state
image
uptime
```

Example:

```
Docker
─────────────────
● api
● postgres
● redis
✕ collector
```

Actions:

* start
* stop
* restart
* logs

Do not expose arbitrary Docker commands from the client.

---

# 18. V0.1 Developer Dashboard

The default interface should communicate useful state.

A rough conceptual layout:

```
┌─────────────────────────────┐
│ TACT                        │
│ Development                 │
├─────────────────────────────┤
│ PROJECT                     │
│ optilab                     │
│ main ↑2 ↓0                 │
├─────────────────────────────┤
│ SYSTEM                      │
│ CPU 34%   RAM 61%           │
├─────────────────────────────┤
│ DOCKER                      │
│ ● api                       │
│ ● postgres                  │
│ ✕ collector                 │
├─────────────────────────────┤
│ [RUN] [TEST] [BUILD]        │
│ [GIT] [DOCKER] [TERMINAL]   │
└─────────────────────────────┘
```

This is only a conceptual reference.

Do not blindly copy this exact layout.

The UI should remain modular.

---

# 19. V0.2 — Event System

The major objective of V0.2 is:

> **Tact should tell the developer when something important happens.**

Implement a central event bus inside the desktop agent.

Conceptually:

```
Integration
    │
    ▼
Event Bus
    │
    ├── WebSocket
    ├── Notification system
    ├── State manager
    └── Logs
```

Events should have:

* event ID
* event type
* timestamp
* severity
* source
* title
* message
* optional metadata
* optional actions

Example:

```
{
  "type": "build.failed",
  "severity": "error",
  "source": "vscode",
  "title": "Build Failed",
  "message": "collector.py:182",
  "actions": [
    "open.error",
    "debug.error",
    "rebuild"
  ]
}
```

---

# 20. V0.2 Events

Implement at least:

### Build

```
build.started
build.succeeded
build.failed
```

### Tests

```
tests.started
tests.passed
tests.failed
```

### Docker

```
container.started
container.stopped
container.failed
```

### Git

```
repository.changed
branch.changed
```

### System

```
battery.low
high.resource_usage
```

Only implement events that can be detected reliably.

Do not fake events.

---

# 21. Actionable Notifications

A notification should not simply say:

```
BUILD FAILED
```

It should allow actions.

Example:

```
BUILD FAILED
collector.py:182

[OPEN]
[DEBUG]
[REBUILD]
```

The user should be able to interact with these directly from the phone.

---

# 22. Developer Notification Feed

Create a Tact notification/event feed.

Example:

```
TACT
──────────────────────────

14:32  BUILD FAILED
       optilab-api

14:27  TEST FAILED
       2 tests

14:10  DOCKER
       postgres stopped

13:54  GIT
       branch changed
```

Events should be filterable by:

* severity
* source
* type

But keep V0.2 UI simple.

---

# 23. Context Detection

Implement the first version of a context engine.

Initially, context may simply be:

```
active_application
```

Examples:

```
vscode
chrome
spotify
terminal
teams
```

Do not attempt advanced AI workflow inference yet.

The architecture should nevertheless allow richer context later.

Future context may include:

* active application
* active window
* project
* Git branch
* running development services
* meeting state
* media state
* development events

---

# 24. Context-Aware Layouts

Once active application detection works:

```
VS Code
   ↓
development layout

Spotify
   ↓
media layout

Teams
   ↓
meeting layout
```

However, V0.2 does not need to support every application.

Focus primarily on:

```
VS Code
terminal
Docker
Git
```

The architecture should make adding other integrations straightforward.

---

# 25. Persistence

Use local persistence only.

Suitable options:

* SQLite
* JSON configuration files

Persist:

* device pairing
* user preferences
* layouts
* enabled integrations
* notification settings

Do NOT introduce cloud accounts or cloud synchronization yet.

---

# 26. Pairing and Security

For the MVP, the phone and laptop communicate over the local network.

Do not assume the local network is trusted.

Implement basic pairing.

Recommended flow:

1. Desktop agent starts.
2. It generates a temporary pairing token.
3. Desktop displays a QR code or pairing code.
4. Phone scans/enters it.
5. Phone establishes authenticated WebSocket connection.
6. Agent stores the trusted device locally.
7. Future connections require authentication.

Do not expose unrestricted endpoints.

Do not execute arbitrary shell commands received from the phone.

Validate all action IDs.

Validate all payloads using Pydantic or equivalent schemas.

---

# 27. Non-Goals Until V0.2 Is Complete

Do NOT implement:

* native Android application
* native iOS application
* custom hardware
* Raspberry Pi/ESP32 support
* AI-generated workspaces
* AI debugging
* cloud synchronization
* user accounts
* marketplace
* payments
* social features
* multi-user collaboration
* enterprise administration
* dozens of integrations
* Kubernetes integration
* complex plugin marketplace
* microservice architecture

These are future possibilities.

The immediate goal is to prove that the core interaction is useful.

---

# 28. Product Quality Requirements

Tact should feel like a real application even in MVP form.

Prioritize:

### Responsiveness

Button actions should feel immediate.

### Reliability

If the connection drops, the UI should clearly indicate:

```
Disconnected
```

and automatically attempt reconnection.

### Graceful degradation

If Docker is not installed:

```
Docker
Not detected
```

Do not crash the application.

If Git is unavailable:

```
Git
Not available
```

Do not crash.

### Error handling

Errors should become useful events/logs rather than uncaught exceptions.

### Logging

The desktop agent should have structured logs.

Use appropriate log levels:

* DEBUG
* INFO
* WARNING
* ERROR

---

# 29. Testing

Write tests for important domain logic.

At minimum:

* action registry
* action validation
* WebSocket message schemas
* event creation
* context detection
* telemetry collection
* Git integration parsing
* Docker integration parsing

Do not attempt 100% coverage.

Prioritize correctness of core functionality.

---

# 30. Development Method

Work incrementally.

Before implementing a large feature:

1. Understand the existing architecture.
2. Identify affected modules.
3. Make the smallest coherent change.
4. Run tests.
5. Run lint/type checks where configured.
6. Manually test the feature.
7. Update documentation if behavior changed.

Do not rewrite working components unnecessarily.

Do not introduce dependencies without justification.

Do not over-engineer for hypothetical future requirements.

---

# 31. Product Design Principles

Follow these principles throughout development.

## Principle 1 — Information + Control

Every useful Tact screen should ideally answer:

> What is happening?

and:

> What can I do about it?

## Principle 2 — Context over static macros

The interface should eventually adapt to what the developer is doing.

## Principle 3 — Declarative UI

The desktop agent describes the interface; the client renders it.

## Principle 4 — Events are first-class

Important development events should be able to update the Tact interface immediately.

## Principle 5 — Local-first

Tact should work without cloud infrastructure.

## Principle 6 — Developer-first

Prioritize software development workflows over generic consumer remote-control features.

## Principle 7 — Extensible

Adding a new integration should not require rewriting the core.

---

# 32. Future Vision — Do Not Implement Yet

Keep the following architecture in mind, but do not implement it prematurely.

## AI-generated workspace

Eventually:

User installs Tact.

Tact detects:

```
VS Code
Docker
Git
Chrome
Spotify
Teams
ChatGPT
```

Tact can generate:

```
Development
Communication
Productivity
AI
```

layouts automatically.

The AI should help with **configuration and workflow composition**, not merely provide a chatbot.

## AI debugging

Eventually:

```
BUILD FAILED
collector.py:182

[OPEN]
[EXPLAIN]
[DEBUG WITH AI]
[REBUILD]
```

The AI could consume relevant error/context and route it to the user's configured AI provider.

## Provider-agnostic AI

Potential future providers:

* OpenAI
* Anthropic
* Google
* local models
* coding assistants

Do not couple the entire product to one provider.

## Physical Tact

Eventually, the same Tact protocol could power a dedicated hardware control surface.

But hardware is explicitly out of scope for the current development phase.

---

# 33. Definition of Done — V0.1

V0.1 is complete when:

1. The Tact desktop agent runs locally.
2. A phone can connect over LAN.
3. The phone renders a responsive Tact interface.
4. WebSocket communication works reliably.
5. The phone can execute safe registered actions.
6. System telemetry is displayed.
7. VS Code integration provides useful controls.
8. Git state is displayed.
9. Docker state is displayed when Docker exists.
10. Layouts are represented declaratively.
11. The connection automatically reconnects.
12. Basic pairing/authentication exists.
13. Important code paths have tests.
14. README explains how to install and run the MVP.
15. The developer can realistically use Tact during a coding session.

---

# 34. Definition of Done — V0.2

V0.2 is complete when:

1. A central event bus exists.
2. Build events are detected.
3. Test events are detected.
4. Docker state changes generate events.
5. Git state changes generate events.
6. Events reach the mobile client in real time.
7. Tact displays a developer notification/event feed.
8. Notifications can contain actions.
9. Build failures can expose actions such as:

   * Open
   * Debug
   * Rebuild
10. Context detection can identify the active development application.
11. Layouts can respond to context.
12. Connection/security/error handling is robust.
13. The system remains local-first.
14. The codebase remains modular enough to add future integrations.

---

# 35. How You Should Work as the Coding Agent

Do not simply start writing hundreds of files.

First inspect the repository and determine its current state.

Then:

1. Establish the project structure.
2. Create the minimal desktop agent.
3. Create the minimal React client.
4. Establish WebSocket communication.
5. Implement one end-to-end action.
6. Implement the declarative UI protocol.
7. Expand to telemetry and integrations.
8. Implement V0.1.
9. Test V0.1.
10. Only then begin V0.2.

At each stage, favor a working vertical slice over isolated infrastructure.

When making architectural decisions, explain the reasoning briefly in code comments or documentation where appropriate.

Do not ask for permission for every small implementation decision.

Make reasonable engineering decisions independently.

However, if a requirement is genuinely ambiguous and could materially alter the architecture or product behavior, stop and ask for clarification rather than inventing a major feature.

---

# 36. First Task

Your immediate task is NOT to implement the entire roadmap.

First:

1. Inspect the repository.
2. Determine what already exists.
3. Create or refine the architecture for V0.1/V0.2.
4. Identify missing pieces.
5. Create a concise implementation plan.
6. Then begin implementing the first vertical slice:

   ```
   Desktop Agent
         ↓
   WebSocket
         ↓
   Mobile Web Client
         ↓
   Button
         ↓
   Safe laptop action
   ```

The first successful demonstration should be:

> **Open Tact on a phone → see the Tact interface → press a button → observe the laptop respond immediately.**

Everything else should build on this foundation.

Do not over-engineer the MVP.
Do not build features outside the V0.1/V0.2 scope.
Keep Tact developer-focused.
Keep the architecture extensible.
Prioritize making the product genuinely useful.
