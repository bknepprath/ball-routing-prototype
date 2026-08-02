#!/usr/bin/env python3
"""Deterministically render .luna/PRD.html from canonical state.json."""

import argparse
import html
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
STATE = ROOT / "state.json"
OUTPUT = ROOT / "PRD.html"
SUBJECTS = ("operations", "design", "gameplay_systems", "gameplay")
PRODUCT_TABS = (("design", "Design"), ("gameplay_systems", "Gameplay Systems"), ("gameplay", "Gameplay"))
REQUIRED = {"id", "title", "subject", "rank", "status", "checked", "acceptance_criteria", "dependencies", "blockers", "completion_evidence"}


def items(values):
    return "<ul>" + "".join(f"<li>{html.escape(str(value))}</li>" for value in values) + "</ul>" if values else "None"


def row(priority):
    checked = " checked" if priority["checked"] else ""
    return (f'<tr><td><input type="checkbox"{checked} disabled></td><td>{priority["rank"]}</td>'
            f'<td><strong>{html.escape(priority["id"])}</strong> {html.escape(priority["title"])}</td>'
            f'<td>{html.escape(priority["subject"])}</td><td class="status">{html.escape(priority["status"])}</td>'
            f'<td>{items(priority["acceptance_criteria"])}</td><td>{items(priority["dependencies"])}</td>'
            f'<td>{items(priority["blockers"])}</td><td>{items(priority["completion_evidence"])}</td></tr>')


def table(priorities, show_subject=True):
    subject = "<th>Subject</th>" if show_subject else ""
    body = "".join(row(p) if show_subject else row(p).replace(f'<td>{html.escape(p["subject"])}</td>', "", 1) for p in priorities)
    return ('<div class="priority-table"><table><thead><tr><th>Done</th><th>Rank</th><th>Priority</th>' + subject
            + '<th>Status</th><th>Acceptance criteria</th><th>Dependencies</th><th>Blockers</th><th>Completion evidence</th>'
            + f'</tr></thead><tbody>{body}</tbody></table></div>')


def validate(state):
    priorities = state.get("priorities")
    if not isinstance(priorities, list):
        raise ValueError("priorities must be a list")
    ids, ranks = set(), set()
    for priority in priorities:
        missing = REQUIRED - priority.keys()
        if missing:
            raise ValueError(f'{priority.get("id", "priority")} missing fields: {sorted(missing)}')
        if priority["subject"] not in SUBJECTS:
            raise ValueError(f'{priority["id"]} has invalid subject {priority["subject"]!r}')
        if priority["id"] in ids or priority["rank"] in ranks:
            raise ValueError("priority IDs and ranks must be unique")
        if priority["subject"] == "operations" and priority["status"] != "completed":
            raise ValueError("operations is infrastructure/history only; operations priorities must be completed")
        ids.add(priority["id"]); ranks.add(priority["rank"])
    return sorted(priorities, key=lambda value: value["rank"])


def render(state):
    priorities = validate(state)
    panels = []
    for subject, label in PRODUCT_TABS:
        selected = [p for p in priorities if p["subject"] == subject]
        panels.append(f'<section id="{subject}" class="panel"><h2>{label}</h2>{table(selected, False)}</section>')
    completed_operations = [p for p in priorities if p["subject"] == "operations" and p["status"] == "completed"]
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ball Routing Prototype PRD</title><style>
:root{{font:16px/1.5 system-ui,sans-serif;color:#172033;background:#f4f6f8}}body{{max-width:1200px;margin:auto;padding:24px}}h1{{margin:0 0 20px}}.tabs{{display:flex;gap:8px;border-bottom:1px solid #bcc5d1}}.tabs button{{border:0;background:none;padding:12px 16px;font:inherit;cursor:pointer}}.tabs button[aria-selected="true"]{{border-bottom:3px solid #185adb;font-weight:700}}.panel{{display:none;background:#fff;padding:24px}}.panel.active{{display:block}}table{{width:100%;border-collapse:collapse}}th,td{{text-align:left;vertical-align:top;border:1px solid #d8dee8;padding:8px}}th{{background:#eef2f7}}.status{{white-space:nowrap}}ul{{margin:0;padding-left:20px}}@media(max-width:760px){{body{{padding:12px}}.tabs{{overflow:auto}}.panel{{padding:14px}}.priority-table{{overflow:auto}}}}
</style></head><body><h1>Ball Routing Prototype</h1>
<nav class="tabs" aria-label="PRD sections"><button aria-selected="true" aria-controls="overview">Overview</button><button aria-selected="false" aria-controls="design">Design</button><button aria-selected="false" aria-controls="gameplay_systems">Gameplay Systems</button><button aria-selected="false" aria-controls="gameplay">Gameplay</button></nav>
<section id="overview" class="panel active"><h2>Overview</h2><p>Canonical ranked production priorities for the desktop 3D ball-routing game.</p><h3>Combined priority checklist</h3>{table(priorities)}<h3>Completed operations</h3>{table(completed_operations)}</section>
{''.join(panels)}
<script>const buttons=[...document.querySelectorAll('.tabs button')];buttons.forEach(button=>button.addEventListener('click',()=>{{buttons.forEach(item=>item.setAttribute('aria-selected',String(item===button)));document.querySelectorAll('.panel').forEach(panel=>panel.classList.toggle('active',panel.id===button.getAttribute('aria-controls')));}}));</script>
</body></html>
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail if PRD.html differs from rendered state")
    args = parser.parse_args()
    try:
        expected = render(json.loads(STATE.read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"PRD validation failed: {error}", file=sys.stderr)
        return 1
    if args.check:
        actual = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else None
        if actual != expected:
            print(".luna/PRD.html is out of date; run python .luna/render_prd.py", file=sys.stderr)
            return 1
        print("PRD is synchronized with state.json")
        return 0
    OUTPUT.write_text(expected, encoding="utf-8")
    print(f"Rendered {OUTPUT.relative_to(ROOT.parent)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
