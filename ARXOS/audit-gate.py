#!/usr/bin/env python3
"""audit-gate.py: run in the source tree. Fails on any high or critical advisory in the runtime
dependencies (npm audit --omit=dev) that is not listed, by its exact advisory id, in
ARXOS/audit-exceptions.txt. Prints every advisory and why it passed or failed."""
import json, pathlib, subprocess, sys
here = pathlib.Path(__file__).resolve().parent
excepted = {}
for line in (here / "audit-exceptions.txt").read_text().splitlines():
    if line.strip() and not line.startswith("#"):
        parts = line.split(None, 3)
        excepted[parts[0]] = parts[3] if len(parts) > 3 else ""
out = subprocess.run(["npm", "audit", "--omit=dev", "--json"], capture_output=True, text=True).stdout
report = json.loads(out or "{}")
roots = {}
for name, v in report.get("vulnerabilities", {}).items():
    for via in v.get("via", []):
        if isinstance(via, dict):
            gid = (via.get("url") or "").rsplit("/", 1)[-1] or str(via.get("source"))
            roots[gid] = (via.get("severity"), via.get("name", name), via.get("title"))
bad = []
for gid, (sev, pkg, title) in sorted(roots.items()):
    if sev not in ("high", "critical"):
        print(f"  note     {gid} {sev} {pkg}: {title}")
    elif gid in excepted:
        print(f"  excepted {gid} {sev} {pkg}: {title}\n           reviewed: {excepted[gid][:160]}")
    else:
        print(f"  FAIL     {gid} {sev} {pkg}: {title}")
        bad.append(gid)
print(f"{len(roots)} advisories, {len(bad)} blocking")
sys.exit(1 if bad else 0)
