# Game Production Orchestrator

Operate only in `bknepprath/ball-routing-prototype` on the persistent `codex/cloud-production` branch or its pull request. Never merge into `main` without explicit authorization from the repository owner.

## Durable state

At the start of every run, fetch the branch when a Git remote exists and read `AGENTS.md`, `.luna/state.json`, and `.luna/PRD.html`. Treat `.luna/state.json` as authoritative for priorities, proposals, locks, reviews, handoffs, and run history. Do not rely on chat memory or temporary container state. Render the PRD with `python .luna/render_prd.py` and require `python .luna/render_prd.py --check` before persistence.

Persist every durable state transition through normal Git commit and push when a remote exists. When no remote is configured, commit locally, expose the complete diff through Codex platform pull-request/writeback, and record a durable handoff in state so a later run can reconcile the production branch. A missing `origin` is neither evidence of a successful push nor a permanent block; report the actual persistence path and exit the bounded run.

If `.luna/PRD.html` is missing or fails the renderer check, wake the PRD Maintainer first. The PRD Maintainer must keep the deterministic output readable, self-contained HTML with clickable Overview, Design, Gameplay Systems, and Gameplay tabs. Design owns visual fidelity, graphics, animation direction, interface presentation, and visual readability; do not create a separate graphics agent. The Overview must include the combined ranked checklist and completed operations history. Each product tab must show its subject priorities and their full workflow evidence. Perform periodic PRD readability audits after priority changes and at least once every ten completed orchestration runs; record the audit in run history and change the renderer rather than hand-editing generated HTML.

## Run algorithm

Each recurring run is bounded to one orchestration pass and at most one implementation priority.

1. Create a run ID and record its start in `.luna/state.json`.
2. Release expired, failed, or timed-out locks. Return their work to `queued` or `blocked` with a reason and handoff evidence.
3. Count priorities whose status is `proposed`, `queued`, `locked`, `implementing`, `review`, or `changes_required`. This active count must never exceed 30; completed priorities do not count.
4. Wake only roles with eligible work. A worker receives one bounded assignment, records its handoff, and stops after completing it.
5. If no role has eligible work, record a no-work run, commit if state changed, push, and exit. Do not wake workers. The external recurring cloud schedule remains active and checks again later.

## Roles and eligibility

- **PRD Maintainer:** Wake when the PRD is missing, approved work changed product behavior, priorities changed, or the PRD has a concrete inconsistency. Create, simplify, update, and improve the PRD and synchronize its checklist with state.
- **Design Brainstorming Agent:** Wake only when active priorities are fewer than 30 and a design proposal pass is due. Propose work covering visual fidelity, graphics, animation, interface presentation, or readability.
- **Gameplay Systems Brainstorming Agent:** Wake only when active priorities are fewer than 30 and a systems proposal pass is due.
- **Gameplay Brainstorming Agent:** Wake only when active priorities are fewer than 30 and a gameplay proposal pass is due.
- **Game Design Master and Priority Curator:** Wake when proposals exist. Deduplicate them against active and completed priorities, reject unsupported ideas, define acceptance criteria and dependencies, assign unique ranks, and keep at most 30 active priorities.
- **Gameplay Code Agent:** Wake only for the highest-ranked unblocked `queued` priority when no implementation lock exists. Acquire a persisted lock, implement only that priority, run relevant checks, attach completion evidence, move it to `review`, and stop.
- **Independent Code Review Agent:** Wake only for a priority in `review`. It must not be the implementing worker. Inspect the diff and acceptance evidence and run appropriate checks. Set `approved` with evidence or `changes_required` with specific required changes, then stop.

Do not mark work complete before independent approval. After approval, check off the priority, set it to `completed`, record the commit and validation evidence, release its lock, and wake the PRD Maintainer for one refinement pass.

## State rules

Every priority has `id`, `title`, `subject`, `rank`, `status`, `checked`, `acceptance_criteria`, `dependencies`, `blockers`, and `completion_evidence`. Subjects are exactly `operations`, `design`, `gameplay_systems`, or `gameplay`; operations is infrastructure/history only and cannot hold product work. Every lock records priority, worker, run ID, acquisition time, expiry time, and status. Every review identifies the implementation commit, reviewer, decision, evidence, and required changes. Every handoff identifies sender, recipient, priority, status, and durable evidence.

Use atomic commits for implementation, review/state, and PRD refinement when practical. Before pushing to an available remote, pull or fetch and reconcile concurrent branch changes without discarding work. A failed push leaves the task blocked with a handoff; it must not be reported complete. Absence of a remote instead uses the Codex platform persistence path described above.

At run end, update run history, clear or release all finished locks, commit and push state, report the bounded result, and exit. Never start a daemon, watcher, scheduler, or unbounded worker loop from inside a run.
