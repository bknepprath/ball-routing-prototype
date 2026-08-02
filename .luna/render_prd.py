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

PRODUCT_CONTENT = {
    "design": '''<h3>Visual fidelity and graphics</h3><p>Use the existing stylized mechanical tower, sky-island setting, beveled wood structures, saturated interaction colors, and mobile renderer. New assets must match the existing authored geometry and materials.</p>
<h3>Animation direction</h3><p>Motion must explain game state: balls travel continuously, gates visibly open, moving obstacles show their effect, and upgrades produce immediate feedback. Avoid decorative animation that obscures ball motion.</p>
<h3>Interface presentation</h3><p>Keep the primary action, credits, damage state, upgrade costs, and current upgrade effects visible. Secondary controls may remain behind the existing options control.</p>
<h3>Visual readability</h3><p>Maintain clear contrast between balls, route surfaces, hazards, gates, labels, and the background. Preserve readable labels from the default camera and at the 1440×900 target viewport.</p>''',
    "gameplay_systems": '''<ul><li>Ball spawning: manual and automatic spawning with a 300-ball cap and limited shadow casters.</li><li>Economy: credits fund spawn-rate, ball-value, and ball-damage upgrades.</li><li>Damage gates: moving balls damage gates; lethal hits open the route without deleting the traversing ball.</li><li>Route generation: eleven unique attachment types connect through entry and exit ports.</li><li>Traversal: motion assists, conveyors, portals, moving obstacles, and finish detection keep balls moving through the route.</li><li>Camera and interface: keyboard and mouse camera controls, interface visibility, and compact optional controls.</li></ul>''',
    "gameplay": '''<ol><li>Drop balls into the funnel.</li><li>Use ball impacts to open the entry gate.</li><li>Route balls through all eleven generated sections to the finish.</li><li>Earn credits and choose upgrades for spawn rate, value, or damage.</li><li>Generate another route and continue progression.</li></ol>
<h3>Controls</h3><table><tbody><tr><th>Space</th><td>Drop a ball</td></tr><tr><th>1 / 2 / 3</th><td>Buy spawn-rate, ball-value, or ball-damage upgrade</td></tr><tr><th>T</th><td>Toggle automatic spawning</td></tr><tr><th>G</th><td>Generate a new route</td></tr><tr><th>W / A / S / D, E / C</th><td>Move the camera</td></tr><tr><th>Middle drag / Shift + middle drag / wheel</th><td>Orbit, pan, and zoom</td></tr><tr><th>Tab</th><td>Hide or show the interface</td></tr><tr><th>R</th><td>Reset the camera</td></tr></tbody></table>''',
}


def items(values):
    return "<ul>" + "".join(f"<li>{html.escape(str(value))}</li>" for value in values) + "</ul>" if values else "None"


def workflow_evidence(priority, state):
    entries = []
    for review in state.get("reviews", []):
        if review["priority"] == priority["id"]:
            entries.append("<h4>Review</h4><dl>"
                           f'<dt>Implementation commit</dt><dd>{html.escape(review["implementation_commit"])}</dd>'
                           f'<dt>Reviewer</dt><dd>{html.escape(review["reviewer"])}</dd>'
                           f'<dt>Decision</dt><dd>{html.escape(review["decision"])}</dd>'
                           f'<dt>Validation evidence</dt><dd>{items(review["evidence"])}</dd>'
                           f'<dt>Required changes</dt><dd>{items(review["required_changes"])}</dd></dl>')
    for handoff in state.get("handoffs", []):
        if handoff["priority"] == priority["id"]:
            entries.append("<h4>Handoff</h4><dl>"
                           f'<dt>Sender</dt><dd>{html.escape(handoff["sender"])}</dd>'
                           f'<dt>Recipient</dt><dd>{html.escape(handoff["recipient"])}</dd>'
                           f'<dt>Status</dt><dd>{html.escape(handoff["status"])}</dd>'
                           f'<dt>Durable evidence</dt><dd>{items(handoff["durable_evidence"])}</dd></dl>')
    return "".join(entries) or "None"


def row(priority, state):
    checked = " checked" if priority["checked"] else ""
    return (f'<tr><td><input type="checkbox"{checked} disabled></td><td>{priority["rank"]}</td>'
            f'<td><strong>{html.escape(priority["id"])}</strong> {html.escape(priority["title"])}</td>'
            f'<td>{html.escape(priority["subject"])}</td><td class="status">{html.escape(priority["status"])}</td>'
            f'<td>{items(priority["acceptance_criteria"])}</td><td>{items(priority["dependencies"])}</td>'
            f'<td>{items(priority["blockers"])}</td><td>{items(priority["completion_evidence"])}</td>'
            f'<td>{workflow_evidence(priority, state)}</td></tr>')


def table(priorities, state, show_subject=True):
    subject = "<th>Subject</th>" if show_subject else ""
    body = "".join(row(p, state) if show_subject else row(p, state).replace(f'<td>{html.escape(p["subject"])}</td>', "", 1) for p in priorities)
    return ('<div class="priority-table"><table><thead><tr><th>Done</th><th>Rank</th><th>Priority</th>' + subject
            + '<th>Status</th><th>Acceptance criteria</th><th>Dependencies</th><th>Blockers</th><th>Completion evidence</th><th>Workflow evidence</th>'
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
    for kind, fields in (("review", {"priority", "implementation_commit", "reviewer", "decision", "evidence", "required_changes"}),
                         ("handoff", {"priority", "sender", "recipient", "status", "durable_evidence"})):
        for record in state.get(f"{kind}s", []):
            missing = fields - record.keys()
            if missing:
                raise ValueError(f"{kind} missing fields: {sorted(missing)}")
            if record["priority"] not in ids:
                raise ValueError(f'{kind} references unknown priority {record["priority"]!r}')
    return sorted(priorities, key=lambda value: value["rank"])


def render(state):
    priorities = validate(state)
    panels = []
    for subject, label in PRODUCT_TABS:
        selected = [p for p in priorities if p["subject"] == subject]
        panels.append(f'<section id="{subject}" class="panel"><h2>{label}</h2>{PRODUCT_CONTENT[subject]}<h3>Priorities</h3>{table(selected, state, False)}</section>')
    completed_operations = [p for p in priorities if p["subject"] == "operations" and p["status"] == "completed"]
    rendered = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ball Routing Prototype PRD</title><style>
:root{{font:16px/1.5 system-ui,sans-serif;color:#172033;background:#f4f6f8}}body{{max-width:1200px;margin:auto;padding:24px}}h1{{margin:0 0 20px}}.tabs{{display:flex;gap:8px;border-bottom:1px solid #bcc5d1}}.tabs button{{border:0;background:none;padding:12px 16px;font:inherit;cursor:pointer}}.tabs button[aria-selected="true"]{{border-bottom:3px solid #185adb;font-weight:700}}.panel{{display:none;background:#fff;padding:24px}}.panel.active{{display:block}}table{{width:100%;border-collapse:collapse}}th,td{{text-align:left;vertical-align:top;border:1px solid #d8dee8;padding:8px}}th{{background:#eef2f7}}.status{{white-space:nowrap}}ul{{margin:0;padding-left:20px}}@media(max-width:760px){{body{{padding:12px}}.tabs{{overflow:auto}}.panel{{padding:14px}}.priority-table{{overflow:auto}}}}
</style></head><body><h1>Ball Routing Prototype</h1>
<nav class="tabs" aria-label="PRD sections"><button aria-selected="true" aria-controls="overview">Overview</button><button aria-selected="false" aria-controls="design">Design</button><button aria-selected="false" aria-controls="gameplay_systems">Gameplay Systems</button><button aria-selected="false" aria-controls="gameplay">Gameplay</button></nav>
<section id="overview" class="panel active"><h2>Overview</h2><p>Canonical ranked production priorities for the desktop 3D ball-routing game.</p><h3>Combined priority checklist</h3>{table(priorities, state)}<h3>Completed operations</h3>{table(completed_operations, state)}</section>
{''.join(panels)}
<script>const buttons=[...document.querySelectorAll('.tabs button')];buttons.forEach(button=>button.addEventListener('click',()=>{{buttons.forEach(item=>item.setAttribute('aria-selected',String(item===button)));document.querySelectorAll('.panel').forEach(panel=>panel.classList.toggle('active',panel.id===button.getAttribute('aria-controls')));}}));</script>
</body></html>
'''
    for review in state.get("reviews", []):
        if html.escape(review["implementation_commit"]) not in rendered or html.escape(review["reviewer"]) not in rendered:
            raise ValueError(f'review evidence for {review["priority"]} disappeared from rendered output')
    for handoff in state.get("handoffs", []):
        if html.escape(handoff["sender"]) not in rendered or html.escape(handoff["recipient"]) not in rendered:
            raise ValueError(f'handoff evidence for {handoff["priority"]} disappeared from rendered output')
    return rendered


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
