# GitHub roadmap audit

Audit date: 2026-08-25. The repository had 70 open issues across 12 open
milestones plus one unscheduled issue. “Implemented” means the complete issue
scope has direct repository evidence. “Partial” means at least one acceptance
item remains, so the issue stays open.

## V0.1 — Developer Control Surface

| Issue | Scope | Audit |
| --- | --- | --- |
| #3 | Docker container list | Closed: agent snapshot and phone/native lists |
| #4 | Docker start/stop/restart | Closed: allowlisted actions and phone controls |
| #5 | Docker phone status widget | Closed: Flutter card and native developer views |
| #6 | Battery telemetry | Closed: agent telemetry and mobile rendering |
| #7 | Hostname, OS, uptime | Open: these three fields are not complete |
| #8 | Declarative layout protocol | Partial: context surfaces are declarative; all hardcoded tabs are not replaced |

## V0.2 — Developer State & Event System

| Issue | Scope | Audit |
| --- | --- | --- |
| #9 | Build started/succeeded/failed events | Open |
| #10 | Test started/passed/failed events | Open |
| #11 | Docker lifecycle events | Partial: state-change events exist; lifecycle taxonomy remains |
| #12 | Battery/resource events | Open: telemetry exists; threshold events remain |
| #13 | Build status detection | Open |
| #14 | Test status detection | Open |
| #15 | Unified developer status cards | Partial |
| #16 | Actionable event notifications | Partial: action metadata exists; notification delivery remains |
| #17 | Execute notification actions from phone | Partial |
| #18 | Event feed filtering | Partial: dismiss/read and Apple filters exist |
| #19 | CI status integration | Open |

## V0.3 — Developer Cockpit / Home

| Issue | Scope | Audit |
| --- | --- | --- |
| #20 | Developer health hero | Partial |
| #21 | Current project workspace | Partial |
| #22 | Unified controls page | Partial |
| #23 | Workspace abstraction | Partial |
| #24 | Multiple workspace pages | Open |
| #25 | Persist workspace state | Partial |
| #26 | Rich widget library | Partial |

## V0.4 — PC Companion

| Issue | Scope | Audit |
| --- | --- | --- |
| #27 | Brightness and dimming | Partial: Linux brightness control exists |
| #28 | Open and focus applications | Closed: discovery, open, focus, and phone UI |
| #29 | Remote lock, wake, screen control | Partial: lock exists; wake/screen scope remains |
| #30 | Clipboard manager | Partial: history/read/write exist; app/terminal routing remains |
| #31 | Quick Capture | Open |
| #32 | Developer notification mirroring | Open |
| #33 | Locate cursor | Open |

## V0.5 — Developer Workflows

| Issue | Scope | Audit |
| --- | --- | --- |
| #34 | Start Work workflow | Partial: project environment launcher exists |
| #35 | Debug Environment workflow | Partial |
| #36 | Meeting workflow | Partial |
| #37 | Multi-action macro execution | Open |
| #38 | Custom command builder | Open |

## V0.6 — Deep Developer Integrations

| Issue | Scope | Audit |
| --- | --- | --- |
| #39 | GitHub/GitLab integration | Open |
| #40 | Database monitoring/control | Open |
| #41 | Process/service monitor | Open |
| #42 | Terminal jobs with live output | Open |
| #43 | Find and open a file | Partial: VS Code open-file action exists |
| #44 | Meeting controls | Partial: Teams exists; Slack/Zoom remain |
| #45 | AI tool integration foundations | Open |

## V0.7 — Context-Aware Tact

| Issue | Scope | Audit |
| --- | --- | --- |
| #46 | Context engine | Closed: app/window/project/repo/branch/service signals |
| #47 | Context-aware layouts | Closed: automatic registered app surfaces |
| #48 | Development workflow detection | Partial: editor/terminal/Git/Docker exist; database remains |
| #49 | Manual context override | Closed: set/clear actions and phone pin/switch UI |

## V0.8 — Glanceability & Mobile UX

| Issue | Scope | Audit |
| --- | --- | --- |
| #50 | Android home-screen widget | Open |
| #51 | Mobile media widget | Open |
| #52 | Notification-area quick actions | Open |
| #53 | Native notifications and haptics | Open |

## V0.9 — Plugin / Customization Platform

| Issue | Scope | Audit |
| --- | --- | --- |
| #54 | Plugin API | Open |
| #55 | Plugin security boundaries | Open |
| #56 | Profiles/pages/custom widgets/variables | Open |
| #57 | Plugin marketplace | Open |

## V1.0 — AI Workspace Generation + Assistant

| Issue | Scope | Audit |
| --- | --- | --- |
| #58 | Inspect authorized environment | Open |
| #59 | Generate Tact workspace | Open |
| #60 | Edit generated workspace | Open |
| #61 | Provider-agnostic architecture | Open |
| #62 | Build-failure assistant | Open |
| #63 | Context gathering and code-change confirmation | Open |

## V1.1 — Productization

| Issue | Scope | Audit |
| --- | --- | --- |
| #64 | Simple installer flow | Open |
| #65 | Windows/Linux/macOS packaging | Partial: native projects exist; release installers remain |
| #66 | Onboarding and updates | Partial |
| #67 | Performance/reliability/diagnostics | Partial |
| #68 | Free/Pro boundary | Open |
| #69 | Cloud/sync evaluation | Partial: account device registry exists; evaluation remains |

## V2.0 — Physical Tact Hardware

| Issue | Scope | Audit |
| --- | --- | --- |
| #70 | Validate demand for physical Tact | Open, intentionally deferred |
| #71 | Define physical Tact architecture | Open, intentionally deferred |

## Unscheduled

Issue #1 remains open. Its low-latency item is complete, but programmable
buttons, app profiles, and general shortcut mapping are not all complete.
