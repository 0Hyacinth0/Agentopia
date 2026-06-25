#!/usr/bin/env python3
"""Rolling token throughput dashboard for Agentopia.

Reads token_usage.jsonl (written by run_with_monitor.py) and prints stats
every 15s. Tracks cache hit %, in/out tokens, and projects 5h consumption.

Designed for 火山方舟 Coding Plan limit observation.
"""
from __future__ import annotations
import json, os, sys, time
from pathlib import Path
from datetime import datetime, timedelta
from collections import deque

ROOT = Path(__file__).resolve().parent.parent
LOG_PATH = ROOT / "token_usage.jsonl"

def fmt(n):
    n = float(n)
    for u in ["", "K", "M", "B"]:
        if abs(n) < 1000: return f"{n:7.2f}{u}"
        n /= 1000
    return f"{n:7.2f}T"

def load_all():
    """Return list of entries."""
    if not LOG_PATH.exists():
        return []
    out = []
    with LOG_PATH.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                e = json.loads(line)
                if "prompt" in e:
                    out.append(e)
            except json.JSONDecodeError:
                continue
    return out

def main():
    print(f"[mon] watching {LOG_PATH}")
    print(f"[mon] Ctrl+C to stop. Run starts at first call.")
    t_wall_start = time.time()
    last_n = 0
    last_t = t_wall_start
    last_total = 0
    recent = deque(maxlen=20)  # last 20 calls for instantaneous rate

    while True:
        try:
            entries = load_all()
            n = len(entries)

            if n == 0:
                print(f"[{datetime.now():%H:%M:%S}] waiting for first call...", flush=True)
                time.sleep(5)
                continue

            t_run_start = entries[0]["t"]
            t_run_now = entries[-1]["t"]
            elapsed = t_run_now - t_run_start

            prompt = sum(e["prompt"] for e in entries)
            completion = sum(e["completion"] for e in entries)
            total = prompt + completion
            cached = sum(e.get("cached", 0) for e in entries)
            cache_pct = (cached / prompt * 100) if prompt else 0

            # billable tokens: assume cached counts at 10% rate (ark-typical)
            # actual depends on provider, this is just to project
            non_cached = prompt - cached
            billable_est = non_cached + completion

            rate_total = total / elapsed if elapsed else 0
            rate_billable = billable_est / elapsed if elapsed else 0

            # projection to 5h limit (assume 50M billable token cap as guess)
            proj_5h_total = rate_total * 3600 * 5
            proj_5h_billable = rate_billable * 3600 * 5

            # latency stats from recent
            recent_dts = [e.get("dt", 0) for e in entries[-20:]]
            avg_lat = sum(recent_dts)/len(recent_dts) if recent_dts else 0

            # delta since last poll
            delta = ""
            now_wall = time.time()
            if last_n and now_wall > last_t:
                dn = n - last_n
                dtok = total - last_total
                dt = now_wall - last_t
                delta = f" | Δ{dn}calls Δ{fmt(dtok/dt)}tok/s"

            print(
                f"[{datetime.now():%H:%M:%S}] run+{elapsed:>6.0f}s | "
                f"calls={n:>5} (lat~{avg_lat:.1f}s) | "
                f"in={fmt(prompt)} out={fmt(completion)} cached={fmt(cached)}({cache_pct:4.1f}%) | "
                f"total={fmt(total)} billable~{fmt(billable_est)} | "
                f"rate={fmt(rate_total)}/s tot={fmt(rate_total*3600)}/h | "
                f"5h_proj: total={fmt(proj_5h_total)} bill~{fmt(proj_5h_billable)}"
                f"{delta}",
                flush=True
            )
            last_n = n
            last_t = now_wall
            last_total = total
            time.sleep(15)
        except KeyboardInterrupt:
            print("\n[mon] stop")
            break

if __name__ == "__main__":
    main()
