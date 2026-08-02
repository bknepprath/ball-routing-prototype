# Project instructions

## Project

- Godot 4.5.1 desktop 3D game. Open `project.godot`; the main scene is `main.tscn`.
- Runtime code is GDScript in `scripts/`. Blender source-generation scripts in `blender/` require Blender and are not part of normal validation.
- Do not edit generated `.godot/` content or regenerate Blender assets unless the task requires it.
- Preserve unrelated working-tree changes. Do not merge or push to `main` without explicit user authorization.

## Setup

- In Codex Cloud, use `.codex/setup.sh` as the environment setup script.
- The setup script installs Godot 4.5.1 at `$HOME/.local/bin/godot`.

## Validation

Run the smallest relevant check, then the full bounded suite before approval:

```bash
python tests/test_project_files.py
timeout 180 godot --headless --path . --editor --quit
timeout 180 godot --headless --path . --script tests/test_room_runtime.gd
timeout 180 godot --headless --path . --script tests/test_level_chain_runtime.gd
timeout 180 godot --headless --path . --script tests/test_multi_ball_flow_runtime.gd
timeout 180 godot --headless --path . --script tests/test_ball_load_runtime.gd
```

The slower acceptance checks are:

```bash
timeout 180 godot --headless --path . --script tests/test_end_to_end_runtime.gd
timeout 180 godot --headless --path . --script tests/test_traversability_stress.gd
```

There is no separate build step. Godot imports and validates the project with the editor command above.

## Cloud production workflow

- Read `.luna/CLOUD_ORCHESTRATOR_PROMPT.md`, `.luna/state.json`, and `.luna/PRD.html` before production work.
- `.luna/state.json` is authoritative for queues, locks, reviews, and handoffs. Persist every transition in the repository.
- Use the dedicated `codex/cloud-production` branch or its pull request. Never merge into the default branch without explicit user authorization.
- Each run must be bounded, release failed or expired locks, persist results, and exit.
- After changing `.luna/state.json` or the PRD renderer, regenerate with `python .luna/render_prd.py`; validate committed PRD synchronization with `python .luna/render_prd.py --check`.
