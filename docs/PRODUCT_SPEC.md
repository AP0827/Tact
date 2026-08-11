# Tact — Developer Productivity Control Surface

## Complete Product & Engineering Specification

You are the primary coding agent responsible for developing **Tact**, a developer-focused software product that turns a user's mobile device into a dynamic second interface for their computer.

You should operate as a senior software engineer, systems architect, and product engineer.

Prioritize:

* working software
* clean architecture
* incremental development
* security
* maintainability
* excellent UX
* developer usefulness
* product validation

Do not over-engineer for hypothetical future requirements.

---

# 1. PRODUCT CONTEXT

## 1.1 What is Tact?

Tact is a **developer-focused second interface for a computer**.

The user's phone acts as a programmable control surface and information panel for their laptop/desktop.

The computer runs a lightweight **Tact Desktop Agent**.

The phone connects to that agent over the local network and renders a dynamic interface.

The fundamental architecture is:

```text
                    COMPUTER
                        │
              ┌─────────▼─────────┐
              │   TACT AGENT      │
              │                   │
              │ Context           │
              │ Telemetry         │
              │ Actions           │
              │ Events            │
              │ Layouts           │
              └─────────┬─────────┘
                        │
                  WebSocket / LAN
                        │
              ┌─────────▼─────────┐
              │    TACT CLIENT    │
              │                   │
              │ Mobile Web UI     │
              │ Controls          │
              │ Widgets           │
              │ Notifications     │
              └───────────────────┘
```

The laptop is the **brain**.

The phone is the **interface**.

---

# 2. PRODUCT THESIS

Tact is NOT intended to initially be another Stream Deck clone.

Existing products already prove that phones can act as customizable control surfaces.

The central Tact thesis is:

> **Tact is a dynamic second interface for developers: it understands what the developer is doing, displays relevant state and information, and provides contextual actions to interact with the workflow.**

The key distinction is:

> **Tact provides both state and control, not merely buttons.**

A useful Tact screen should answer two questions:

1. What is happening?
2. What can I do about it?

---

# 3. TARGET USER

The initial target user is:

> **A software developer who spends significant time working from a laptop/desktop, particularly remote developers, freelancers, startup engineers, students, and independent developers.**

The primary workflow includes:

* VS Code
* JetBrains IDEs
* Git
* GitHub/GitLab
* Docker
* terminal
* databases
* browser
* Spotify
* Teams / Slack / Zoom
* ChatGPT / Claude / Gemini
* coding agents

The product should be **developer-first**, not generic remote-control software.

---

# 4. PRODUCT DIFFERENTIATION

Tact should eventually differentiate through:

1. Developer-first workflows
2. Rich developer information
3. Context-aware interfaces
4. Event-driven notifications
5. Development-state monitoring
6. Actionable developer notifications
7. Rich widgets rather than button grids
8. Declarative UI/action protocol
9. Extensible integrations
10. AI-generated workspaces
11. AI-assisted debugging workflows
12. Workflow-aware interfaces
13. Local-first architecture
14. Eventually, dedicated Tact hardware

Do not attempt to implement these simultaneously.

They are developed progressively through the roadmap below.

---

# 5. PRODUCT ROADMAP

The product is divided into the following phases:

```text
PHASE 0  — Foundation / Proof of Concept
    ↓
V0.1     — Developer Control Surface
    ↓
V0.2     — Developer Event System
    ↓
V0.3     — Developer Workspace
    ↓
V0.4     — Context-Aware Tact
    ↓
V0.5     — Rich Developer Integrations
    ↓
V0.6     — AI Workspace Generation
    ↓
V0.7     — AI Developer Assistant
    ↓
V0.8     — Plugin / Integration Platform
    ↓
V0.9     — Public Beta / Productization
    ↓
V1.0     — Commercial Developer Product
    ↓
V1.x     — Cloud / Sync / Ecosystem
    ↓
V2.0     — Physical Tact Hardware
```

The exact version numbers are not sacred.

The architectural and product boundaries are more important than the labels.

---

# 6. PHASE 0 — FOUNDATION / PROOF OF CONCEPT

## Goal

Prove the fundamental interaction:

> Phone → Tact → laptop action

The first successful demonstration should be:

```text
Open Tact on phone
        ↓
See Tact interface
        ↓
Press button
        ↓
Laptop responds immediately
```

## Requirements

Create:

* minimal Python desktop agent
* minimal React mobile client
* WebSocket connection
* one declarative button
* one safe laptop action

Example:

```text
Phone
  │
  │ WebSocket
  ▼
Tact Agent
  │
  ▼
system.volume_up
```

## Success criterion

A developer can run Tact locally and control one aspect of the laptop from the phone.

Do not build anything else until this works.

---

# 7. V0.1 — DEVELOPER CONTROL SURFACE

## Goal

Prove that Tact is useful during a real coding session.

## Core integrations

* System
* VS Code
* Git
* Docker

## Core capabilities

* WebSocket communication
* responsive mobile UI
* dynamic UI
* buttons/actions
* system telemetry
* development status
* layouts
* persistent local configuration
* basic pairing

---

## 7.1 Desktop Agent

The agent must:

* start locally
* expose HTTP/WebSocket server
* determine local network address
* accept mobile connection
* maintain connection state
* send initial state
* receive actions
* execute registered actions
* emit events
* handle disconnection
* reconnect safely

Development command:

```bash
python -m tact.agent
```

---

## 7.2 Mobile Client

V0.1 uses a **responsive web application**.

Do NOT build native Android/iOS applications.

The phone should access something similar to:

```text
http://<laptop-ip>:<port>
```

The UI should prioritize:

* portrait mobile screens
* touch
* large controls
* readable information
* low latency

---

## 7.3 System Integration

Display:

* CPU
* RAM
* disk
* battery
* hostname
* OS
* uptime

Use `psutil` where possible.

Use sensible update intervals.

Do not continuously stream unnecessary telemetry.

---

## 7.4 System Actions

Implement:

* volume up
* volume down
* mute
* lock screen
* screenshot

Use a platform abstraction:

```text
SystemController
├── LinuxSystemController
├── WindowsSystemController
└── MacOSSystemController
```

Do not scatter platform-specific logic throughout the codebase.

---

## 7.5 VS Code

Implement practical controls:

* open VS Code
* detect active VS Code
* run
* build
* test
* terminal
* command palette where feasible
* active project/workspace detection where feasible

Do not build a complex VS Code extension unless required.

---

## 7.6 Git

Display:

* repository
* branch
* clean/dirty state
* changed files
* ahead/behind
* latest commit

Actions:

* status
* pull
* push
* commit workflow

Use Git CLI safely.

Do not implement a Git client.

---

## 7.7 Docker

Display:

```text
Docker

● api
● postgres
● redis
✕ collector
```

For each container:

* name
* state
* image
* uptime

Actions:

* start
* stop
* restart
* logs

Do not expose arbitrary Docker commands.

---

# 8. V0.2 — DEVELOPER EVENT SYSTEM

## Goal

Move Tact from:

> remote control

to:

> **developer companion**

The core principle:

> **Tact should tell the developer when something important happens.**

---

## 8.1 Event Bus

Create a central event bus.

```text
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

Every event should contain:

* ID
* type
* timestamp
* severity
* source
* title
* message
* metadata
* optional actions

Example:

```json
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

## 8.2 Events

Implement:

### Build

```text
build.started
build.succeeded
build.failed
```

### Tests

```text
tests.started
tests.passed
tests.failed
```

### Docker

```text
container.started
container.stopped
container.failed
```

### Git

```text
repository.changed
branch.changed
```

### System

```text
battery.low
high.resource_usage
```

Only generate events that can be reliably detected.

Never fake events.

---

## 8.3 Actionable Notifications

Example:

```text
BUILD FAILED

collector.py:182

[OPEN]
[DEBUG]
[REBUILD]
```

The user must be able to execute the action directly from the phone.

---

## 8.4 Developer Event Feed

Create:

```text
TACT
────────────────────

14:32  BUILD FAILED
       optilab-api

14:27  TEST FAILED
       2 tests

14:10  DOCKER
       postgres stopped

13:54  GIT
       branch changed
```

Support basic filtering:

* severity
* source
* type

---

# 9. V0.3 — DEVELOPER WORKSPACE

## Goal

Turn Tact into a persistent **developer dashboard**, rather than a collection of controls.

The user should be able to see the health of their development environment at a glance.

---

## 9.1 Workspace Model

Introduce:

```text
Workspace
 ├── Layout
 ├── Widgets
 ├── Actions
 ├── Integrations
 └── Preferences
```

Example:

```text
OPTILAB WORKSPACE

Git
  branch: feature/collector
  ↑2 ↓0

Build
  ● passing

Tests
  124 / 124

Docker
  ● api
  ● postgres
  ● redis

System
  CPU 34%
  RAM 61%
```

---

## 9.2 Pages

Allow multiple pages:

```text
Development
Infrastructure
Communication
Media
System
```

The user can switch between them.

---

## 9.3 Rich Widgets

Expand widget library:

### Controls

* Button
* Toggle
* Slider
* Dial
* Dropdown

### Information

* Metric
* Status
* Progress
* Notification
* Text
* Timer
* Log
* Graph

Do not create unnecessary widgets.

Prioritize developer use cases.

---

# 10. V0.4 — CONTEXT-AWARE TACT

## Goal

Tact should stop behaving like a static dashboard.

It should understand:

> **What is the developer doing right now?**

---

## 10.1 Context Engine

Initially detect:

* active application
* active window
* active project
* Git repository
* Git branch
* running services

Initial applications:

* VS Code
* terminal
* Chrome
* Spotify
* Teams

---

## 10.2 Context-Aware Layouts

Examples:

```text
VS Code
   ↓
Development layout
```

```text
Spotify
   ↓
Media layout
```

```text
Teams
   ↓
Meeting layout
```

But do not merely clone existing "application profile" systems.

The long-term goal is:

```text
Application
    +
Project
    +
Workflow state
    +
Events
    ↓
Context
    ↓
Relevant Tact interface
```

---

## 10.3 Development Workflow Detection

Eventually detect:

```text
VS Code
+
Terminal
+
Docker
+
Git
+
PostgreSQL
```

and infer:

```text
Development workflow
```

Tact can then show:

```text
DEVELOPMENT

[RUN]
[TEST]
[BUILD]

[DOCKER]
[DATABASE]
[GIT]

Services:
● postgres
● redis
● api
```

This is more valuable than simple application profiles.

---

# 11. V0.5 — DEVELOPER INTEGRATION SUITE

## Goal

Make Tact useful across the actual developer workday.

Add integrations progressively.

---

## Development

* VS Code
* JetBrains IDEs
* Git
* GitHub
* GitLab
* Docker
* terminal
* SSH
* PostgreSQL
* other databases
* CI/CD

---

## Communication

* Microsoft Teams
* Slack
* Discord
* Zoom
* Google Meet

Capabilities:

* meeting state
* mute
* camera
* screen sharing
* meeting timer
* notifications

---

## Productivity

* Chrome
* browser controls
* Spotify
* system controls
* calendar

---

## AI

Support the developer's existing AI tools:

* ChatGPT
* Claude
* Gemini
* coding assistants

Do not make Tact itself a generic chatbot.

---

# 12. V0.6 — AI-GENERATED WORKSPACES

## Goal

Reduce the configuration burden.

The user should not need to manually construct their entire Tact environment.

Tact detects the developer environment:

```text
VS Code
Docker
Git
Chrome
Spotify
Teams
ChatGPT
```

Then offers:

> Generate a workspace?

---

## Example

Tact generates:

```text
DEVELOPMENT

[RUN]
[TEST]
[BUILD]
[GIT]
[DOCKER]
[TERMINAL]

Environment:

CPU 34%
RAM 61%

Docker:
● api
● postgres
● redis
```

Additional pages:

```text
Communication
Media
AI
System
```

---

## AI Design Principle

AI is used primarily for:

* configuration
* layout generation
* workflow composition
* integration selection

It should NOT simply add a chatbot panel.

---

## User modification

The user should be able to say:

> Put Docker and database controls on the first page.

Tact updates the workspace.

---

# 13. V0.7 — AI DEVELOPER ASSISTANT

## Goal

Use Tact as an interface for developer debugging and development workflows.

---

## 13.1 Build Failure Assistant

Example:

```text
BUILD FAILED

collector.py:182

[OPEN]
[EXPLAIN]
[DEBUG WITH AI]
[REBUILD]
```

---

## 13.2 AI Debugging

When the user presses:

```text
DEBUG WITH AI
```

Tact gathers only relevant context, such as:

* error
* file/location
* build output
* test output
* project metadata where explicitly authorized

Then routes it to the user's configured AI provider.

Possible providers:

* OpenAI
* Anthropic
* Google
* local models
* coding assistants

Do not force users into one provider.

---

## 13.3 AI Actions

Eventually:

```text
Explain
Debug
Suggest fix
Open file
Generate patch
Rebuild
Run tests
```

Any action that modifies code must require appropriate user confirmation.

Do not silently modify code.

---

# 14. V0.8 — PLUGIN / INTEGRATION PLATFORM

## Goal

Allow developers and third parties to extend Tact.

---

## Plugin model

A plugin should be able to define:

```text
Integration
 ├── Actions
 ├── Events
 ├── Widgets
 ├── Context providers
 └── Layouts
```

Example:

```text
Docker Plugin

Actions:
 docker.restart
 docker.logs
 docker.start

Events:
 container.failed
 container.stopped

Widgets:
 DockerStatus
 ContainerList
```

---

## Plugin principles

Plugins should not require modification of Tact core.

The core should provide stable APIs.

Security boundaries must be considered carefully.

Do not create a plugin marketplace until the plugin model is stable.

---

# 15. V0.9 — PUBLIC BETA / PRODUCTIZATION

## Goal

Move from developer project to usable public software.

Focus on:

* installation
* onboarding
* pairing
* error handling
* updates
* documentation
* polished UI
* performance
* reliability
* telemetry/diagnostics with explicit consent

---

## 15.1 Installation

The user should eventually be able to:

```text
Download Tact
        ↓
Install
        ↓
Start
        ↓
QR code
        ↓
Scan with phone
        ↓
Connected
```

Avoid requiring users to run Python commands in the commercial product.

---

## 15.2 Desktop Packaging

Package the desktop agent into appropriate platform installers.

Target platforms:

* Windows
* Linux
* macOS

Do not sacrifice architecture quality for cross-platform support too early.

---

## 15.3 Mobile

The existing web client should first become a polished PWA.

Only build native Android/iOS applications if the product has demonstrated a need for:

* better background behavior
* native notifications
* haptics
* Bluetooth
* deeper OS integration
* improved lifecycle handling

Do not build native mobile apps simply because they are technically possible.

---

# 16. V1.0 — COMMERCIAL DEVELOPER PRODUCT

## Goal

Tact becomes a real consumer/prosumer software product.

Potential positioning:

> **Tact — The second interface for developers.**

or:

> **Tact — Your developer cockpit.**

---

# 17. MONETIZATION

Do not optimize monetization before product-market validation.

The likely model is:

## Free

Possible limits:

* one computer
* one mobile device
* basic widgets
* basic integrations
* basic layouts

The free version must be genuinely useful.

---

## Pro

Potentially:

* unlimited layouts
* advanced widgets
* advanced integrations
* workflow detection
* AI workspace generation
* AI debugging
* multiple computers
* cloud sync
* advanced notifications
* custom themes
* advanced automation

Pricing should be determined through user validation.

Do not assume a subscription is automatically correct.

---

# 18. V1.x — CLOUD / SYNC / ECOSYSTEM

Only introduce cloud infrastructure once there is a demonstrated reason.

Potential capabilities:

* account
* cloud layout sync
* device synchronization
* workspace backup
* settings synchronization
* optional AI configuration sync
* marketplace account

Tact must remain useful locally.

Cloud should enhance the product, not become a requirement for basic functionality.

---

# 19. MARKETPLACE

If the plugin ecosystem becomes strong enough, introduce:

```text
Tact Marketplace

Developer
 ├── VS Code Pro Pack
 ├── Docker Pack
 ├── Kubernetes Pack

Creator
 ├── OBS Pack
 ├── Premiere Pack

Productivity
 ├── Slack
 ├── Notion
 └── Linear
```

Potential monetization:

* free plugins
* paid plugins
* creator revenue share

Do not implement this until the plugin ecosystem has actual demand.

---

# 20. V2.0 — PHYSICAL TACT

Only after the software product has established demand.

The original hardware concept can then become:

> **A dedicated physical Tact control surface.**

Potential hardware:

* touchscreen
* physical buttons
* rotary encoders
* USB-C
* wireless
* haptics
* programmable controls

The important point:

> **The hardware should be another client of the Tact platform.**

The same protocol should support:

```text
             TACT PLATFORM
                    │
        ┌───────────┼───────────┐
        ↓           ↓           ↓
      Phone       Tablet      Hardware
        │           │           │
        └───────────┼───────────┘
                    │
               Tact Agent
                    │
                 Computer
```

Do not make hardware the foundation of the software architecture.

---

# 21. FUTURE HARDWARE CONCEPT

The physical product should not merely be:

> "Stream Deck with Tact branding."

It should expose the same capabilities as the software:

* developer telemetry
* build status
* Git state
* Docker state
* notifications
* context-aware layouts
* AI workflows
* rich widgets

Potential form:

```text
┌─────────────────────────────────────┐
│ TACT                                │
│                                     │
│ Build ● Passing     Git ↑2          │
│                                     │
│ Docker                              │
│ ● api  ● postgres  ✕ redis          │
│                                     │
│ [RUN] [TEST] [BUILD]                │
│                                     │
│ [GIT] [DOCKER] [DEBUG]              │
│                                     │
│ CPU 34%       RAM 61%               │
└─────────────────────────────────────┘
```

Physical knobs/buttons can supplement the display.

---

# 22. CORE ARCHITECTURE

The architecture must remain conceptually:

```text
                 TACT DESKTOP AGENT
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
       ▼                 ▼                 ▼
 Context Engine     Telemetry Engine   Event Engine
       │                 │                 │
       └─────────────────┼─────────────────┘
                         │
                    State Manager
                         │
                    Layout Engine
                         │
                    Action Engine
                         │
                  Integration Layer
                         │
                         ▼
                  Tact Protocol
                         │
              ┌──────────┼───────────┐
              ▼          ▼           ▼
           Mobile     Hardware    Future Clients
           Client
```

The protocol should be treated as a major architectural boundary.

---

# 23. TECHNOLOGY STACK

## Desktop Agent

Use:

* Python
* FastAPI
* WebSockets
* Pydantic
* psutil
* subprocess / OS APIs
* SQLite or JSON

## Frontend

Use:

* React
* TypeScript
* Vite
* Tailwind CSS

## Future packaging

Evaluate:

* PyInstaller
* Nuitka
* native packaging
* Tauri
* other appropriate desktop packaging

Do not introduce Tauri merely because it is popular.

---

# 24. DECLARATIVE UI PROTOCOL

This is one of Tact's most important long-term architectural concepts.

The desktop agent should describe the interface.

Example:

```json
{
  "type": "button",
  "id": "vscode.run",
  "label": "Run",
  "action": "vscode.run"
}
```

Metric:

```json
{
  "type": "metric",
  "id": "system.cpu",
  "label": "CPU",
  "value": 42,
  "unit": "%"
}
```

Status:

```json
{
  "type": "status",
  "id": "docker.postgres",
  "label": "PostgreSQL",
  "state": "healthy"
}
```

Notification:

```json
{
  "type": "notification",
  "id": "build.failed",
  "severity": "error",
  "title": "Build Failed",
  "message": "collector.py:182",
  "actions": [
    "open.error",
    "debug.error",
    "rebuild"
  ]
}
```

The client renders these.

Do not hardcode every application into the frontend.

---

# 25. ACTION ARCHITECTURE

Never expose arbitrary shell execution.

Never create:

```text
POST /execute
{
    "command": "..."
}
```

Instead use an allowlisted action registry.

Examples:

```text
system.lock
system.volume_up
system.volume_down

vscode.run
vscode.build
vscode.test

git.status
git.commit
git.push

docker.start
docker.stop
docker.restart
docker.logs
```

Every action must:

* be registered
* be validated
* have an explicit handler
* have appropriate permissions
* produce useful success/failure events

---

# 26. EVENT ARCHITECTURE

Events are first-class objects.

```text
Integration
      ↓
 Event Bus
      ↓
 State Manager
      ↓
 ┌────┼───────────────┐
 ↓    ↓               ↓
UI   Notification   Logging
```

Events may eventually trigger:

* UI updates
* notifications
* actions
* automation
* AI workflows

But automation must be permissioned.

---

# 27. SECURITY PRINCIPLES

Tact controls a computer.

Therefore security is not optional.

Requirements:

* authenticated pairing
* temporary pairing tokens
* device trust
* payload validation
* action allowlisting
* no arbitrary command execution
* local network authentication
* safe defaults
* explicit permissions for dangerous operations
* explicit confirmation for AI-generated code modifications

Never assume LAN = trusted.

---

# 28. LOCAL-FIRST PRINCIPLE

The basic Tact experience must work without:

* cloud
* account
* external server
* internet connection

The phone and computer should communicate locally.

Cloud services may later provide:

* sync
* marketplace
* optional AI services
* backup
* analytics

But local operation remains fundamental.

---

# 29. TESTING STRATEGY

Test important domain logic.

At minimum:

* action registry
* action validation
* WebSocket schemas
* event creation
* context detection
* telemetry
* Git parsing
* Docker parsing
* layout serialization
* notification handling

Do not chase 100% coverage.

Prioritize correctness of the core product.

---

# 30. UX PRINCIPLES

Tact should feel:

* fast
* quiet
* information-dense
* useful
* configurable
* reliable

Avoid:

* excessive animations
* unnecessary gamification
* giant dashboards full of irrelevant information
* decorative UI that reduces information density
* requiring users to configure everything manually

The phone should be something the developer can glance at and immediately understand.

---

# 31. PRODUCT DESIGN PRINCIPLES

### Information + Control

Show state and provide actions.

### Context over static macros

The interface should eventually adapt to what the developer is doing.

### Declarative UI

The agent describes the interface; clients render it.

### Events are first-class

Important events should propagate immediately.

### Developer-first

Prioritize development workflows.

### Local-first

Basic functionality should not depend on cloud services.

### Extensible

New integrations should not require rewriting the core.

### Progressive complexity

Start simple.

Add sophistication only when user behavior demonstrates the need.

---

# 32. NON-GOALS FOR EARLY DEVELOPMENT

Before V0.2 is stable, do NOT implement:

* native Android
* native iOS
* hardware
* Raspberry Pi
* ESP32
* AI workspaces
* AI debugging
* cloud sync
* accounts
* payments
* marketplace
* social features
* enterprise administration
* dozens of integrations
* Kubernetes
* complex plugin marketplace
* microservices

Before V0.5, do not prematurely build:

* full cloud platform
* marketplace
* complex AI infrastructure
* hardware
* enterprise product

The product must earn complexity through demonstrated usage.

---

# 33. DEVELOPMENT PROCESS FOR THE CODING AGENT

At the beginning of every phase:

1. Inspect the current repository.
2. Understand the existing architecture.
3. Review the previous phase's completion status.
4. Identify the smallest coherent implementation.
5. Implement a vertical slice.
6. Run tests.
7. Run lint/type checks.
8. Manually test the feature.
9. Update documentation.
10. Only then continue.

Do not rewrite working architecture without a demonstrated reason.

Do not introduce dependencies without justification.

Do not create abstractions purely for hypothetical future use.

However, preserve the architectural boundaries necessary for future phases.

---

# 34. PHASE GATES

The coding agent must not automatically jump ahead.

## Gate 0 → V0.1

Must demonstrate:

```text
Phone
 ↓
WebSocket
 ↓
Tact Agent
 ↓
Action
 ↓
Laptop
```

## V0.1 → V0.2

Must demonstrate:

* working phone client
* reliable connection
* safe actions
* system telemetry
* VS Code
* Git
* Docker
* declarative UI
* persistence
* pairing

## V0.2 → V0.3

Must demonstrate:

* central event bus
* build events
* test events
* Docker events
* Git events
* actionable notifications
* event feed

## V0.3 → V0.4

Must demonstrate:

* useful dashboard
* multiple layouts/pages
* rich widgets
* persistent workspace

## V0.4 → V0.5

Must demonstrate:

* reliable context detection
* context-aware layouts
* developer workflow detection

## V0.5 → V0.6

Must demonstrate:

* enough integrations to understand a real developer workflow
* users actually configuring/customizing Tact
* clear evidence that configuration complexity is a problem

Only then introduce AI workspace generation.

## V0.6 → V0.7

Must demonstrate:

* generated layouts are useful
* users modify generated layouts
* AI reduces configuration effort

Only then expand AI into debugging.

## V0.7 → V0.8

Must demonstrate:

* meaningful AI developer workflows
* stable integration interfaces
* demand for additional integrations

Only then formalize the plugin platform.

## V0.8 → V0.9

Must demonstrate:

* stable plugin model
* reliable onboarding
* reliable core application

Only then prepare public beta.

## V0.9 → V1.0

Must demonstrate:

* stable public software
* retention
* repeated usage
* users completing real workflows
* evidence of willingness to pay

Only then optimize monetization aggressively.

## V1.x → Hardware

Do not build hardware merely because the original idea included hardware.

Build hardware only if:

* users repeatedly request physical controls
* software usage demonstrates which controls matter
* a viable hardware BOM exists
* there is a clear reason software alone is insufficient

---

# 35. V0.1 DEFINITION OF DONE

V0.1 is complete when:

1. Desktop agent runs locally.
2. Phone connects over LAN.
3. Responsive Tact interface renders.
4. WebSocket communication works.
5. Safe registered actions work.
6. System telemetry is displayed.
7. VS Code integration provides useful controls.
8. Git state is displayed.
9. Docker state is displayed when available.
10. Layouts are declarative.
11. Connection reconnects automatically.
12. Basic pairing/authentication exists.
13. Important code paths have tests.
14. README explains setup.
15. Tact is realistically usable during coding.

---

# 36. V0.2 DEFINITION OF DONE

V0.2 is complete when:

1. Central event bus exists.
2. Build events are detected.
3. Test events are detected.
4. Docker changes generate events.
5. Git changes generate events.
6. Events reach mobile in real time.
7. Notification/event feed exists.
8. Notifications can contain actions.
9. Build failures support Open/Debug/Rebuild actions.
10. Context detection identifies active development application.
11. Layouts can respond to context.
12. Security/error handling is robust.
13. System remains local-first.
14. Architecture remains modular.

---

# 37. V0.3 DEFINITION OF DONE

V0.3 is complete when:

1. Workspace abstraction exists.
2. Multiple pages/layouts exist.
3. Rich widgets exist.
4. Developer dashboard is useful.
5. Workspace state persists.
6. Developer can customize layouts.
7. Dashboard combines information and actions coherently.

---

# 38. V0.4 DEFINITION OF DONE

V0.4 is complete when:

1. Active application detection is reliable.
2. Context engine exists.
3. Context-aware layouts work.
4. Development workflow state can be detected.
5. Tact automatically surfaces relevant controls.
6. User can override automatic context selection.

---

# 39. V0.5 DEFINITION OF DONE

V0.5 is complete when:

1. Core developer integrations are stable.
2. Communication integrations work.
3. Media integration works.
4. AI-tool integration foundations exist.
5. Developer can use Tact across a significant portion of their workday.
6. Integration architecture is stable enough for external extension.

---

# 40. V0.6 DEFINITION OF DONE

V0.6 is complete when:

1. Tact can inspect the user's authorized environment.
2. AI can generate a workspace.
3. Generated workspace uses valid Tact UI primitives.
4. Generated actions are allowlisted.
5. User can edit generated workspace.
6. AI generation does not require a specific AI provider.
7. Generated layouts are actually useful.

---

# 41. V0.7 DEFINITION OF DONE

V0.7 is complete when:

1. Build/test failures can invoke AI workflows.
2. Relevant context can be gathered safely.
3. User can request explanations.
4. User can request debugging assistance.
5. AI-generated modifications require confirmation.
6. Multiple AI providers can be supported.
7. AI remains optional.

---

# 42. V0.8 DEFINITION OF DONE

V0.8 is complete when:

1. Plugin API exists.
2. Plugins can define actions.
3. Plugins can define events.
4. Plugins can define widgets.
5. Plugins can provide layouts.
6. Plugins can provide context.
7. Plugins cannot arbitrarily bypass security boundaries.
8. Core does not need modification for normal integrations.

---

# 43. V0.9 DEFINITION OF DONE

V0.9 is complete when:

1. Installation is simple.
2. Desktop packaging works.
3. Pairing is polished.
4. Onboarding is polished.
5. Error handling is understandable.
6. Documentation is complete.
7. Performance is acceptable.
8. Public beta users can use Tact without developer intervention.

---

# 44. V1.0 DEFINITION OF DONE

V1.0 requires:

* stable desktop software
* stable mobile client/PWA
* reliable pairing
* core developer integrations
* context-aware workflows
* notifications
* workspace system
* AI workspace generation
* optional AI debugging
* plugin architecture
* polished onboarding
* documentation
* privacy/security model
* clear free/pro product boundaries

Most importantly:

> **Real developers must repeatedly choose to use Tact because it makes their work easier.**

---

# 45. FUTURE HARDWARE

Hardware is a future client, not the foundation.

Potential architecture:

```text
                    TACT PLATFORM
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Phone           Tablet        Hardware
          │              │              │
          └──────────────┼──────────────┘
                         │
                    Tact Protocol
                         │
                    Tact Agent
                         │
                      Computer
```

The same declarative UI and action protocol should ideally support all clients.

---

# 46. FINAL DEVELOPMENT INSTRUCTION

You are not being asked to build the entire vision immediately.

You are being asked to build the product **phase by phase**.

At any given moment:

> **Implement only the current phase.**

Preserve architecture that enables later phases, but do not implement future features prematurely.

The current priority is always:

```text
Working software
        >
Architectural elegance
        >
Future-proofing
        >
Feature count
```

A small working feature is better than a large unfinished subsystem.

The first objective remains:

> **Open Tact on a phone → see the Tact interface → press a button → observe the laptop respond immediately.**

Then progressively evolve Tact from:

```text
Remote Control
      ↓
Developer Control Surface
      ↓
Developer Event System
      ↓
Developer Dashboard
      ↓
Context-Aware Workspace
      ↓
Developer Integration Platform
      ↓
AI-Generated Workspace
      ↓
AI Developer Companion
      ↓
Plugin Ecosystem
      ↓
Commercial Product
      ↓
Optional Physical Tact
```

This progression is the product strategy.

Do not skip the validation gates.
Do not build complexity without demonstrated demand.
Do not lose the developer-first identity.
