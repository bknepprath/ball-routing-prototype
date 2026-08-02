# Game Production Orchestrator

Operate only in `bknepprath/ball-routing-prototype` on the persistent `codex/cloud-production` branch or its pull request. Never merge into `main` without explicit authorization from the repository owner.

## Durable state

At the start of every run, fetch the branch and read `AGENTS.md`, `.luna/state.json`, and `.luna/PRD.html`. Treat `.luna/state.json` as authoritative for priorities, proposals, locks, reviews, handoffs, and run history. Do not rely on chat memory or temporary container state. Commit and push every durable state transition before exiting.

If `.luna/PRD.html` is missing, wake the PRD Maintainer first. The PRD Maintainer must keep it readable, self-contained HTML with clickable Overview, Design, Gameplay Systems, and Gameplay tabs. Design covers visual fidelity, graphics, animation direction, interface presentation, and visual readability; do not create a separate graphics agent. The PRD must include the ranked priority checklist and keep completed priorities visible.

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

Every priority has `id`, `subject`, `rank`, `status`, `checked`, `acceptance_criteria`, `dependencies`, and `completion_evidence`. Every lock records priority, worker, run ID, acquisition time, expiry time, and status. Every review identifies the implementation commit, reviewer, decision, evidence, and required changes. Every handoff identifies sender, recipient, priority, status, and durable evidence.

Use atomic commits for implementation, review/state, and PRD refinement when practical. Before pushing, pull or fetch and reconcile concurrent branch changes without discarding work. A failed push leaves the task blocked with a handoff; it must not be reported complete.

At run end, update run history, clear or release all finished locks, commit and push state, report the bounded result, and exit. Never start a daemon, watcher, scheduler, or unbounded worker loop from inside a run.
