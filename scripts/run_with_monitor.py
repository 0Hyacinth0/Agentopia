#!/usr/bin/env python3
"""Live token monitor for Agentopia runs.

Monkey-patches openai.resources.chat.completions.Completions.create to log
every response's .usage to a jsonl file, then tails it and prints rolling stats.

Usage:
  Terminal A:  python scripts/run_with_monitor.py [args passed to run_world.py]
  Terminal B:  python scripts/token_monitor.py    # rolling stats

The patch is applied in run_with_monitor before importing run_world.
"""
from __future__ import annotations
import json, os, sys, time
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parent.parent
LOG_PATH = ROOT / "token_usage.jsonl"

def install_patch():
    """Monkey-patch openai chat.completions.create to log usage."""
    import openai.resources.chat.completions as _cc
    orig = _cc.Completions.create
    log_f = open(LOG_PATH, "a", buffering=1, encoding="utf-8")
    print(f"[patch] logging usage -> {LOG_PATH}", file=sys.stderr)

    def patched(self, *args, **kwargs):
        t0 = time.time()
        r = orig(self, *args, **kwargs)
        try:
            u = getattr(r, "usage", None)
            if u is not None:
                entry = {
                    "t": time.time(),
                    "dt": round(time.time() - t0, 3),
                    "model": getattr(r, "model", kwargs.get("model")),
                    "prompt": getattr(u, "prompt_tokens", 0) or 0,
                    "completion": getattr(u, "completion_tokens", 0) or 0,
                    "total": getattr(u, "total_tokens", 0) or 0,
                }
                pd = getattr(u, "prompt_tokens_details", None)
                if pd is not None:
                    entry["cached"] = getattr(pd, "cached_tokens", 0) or 0
                log_f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        except Exception as e:
            log_f.write(json.dumps({"err": str(e)}) + "\n")
        return r
    _cc.Completions.create = patched

if __name__ == "__main__":
    install_patch()
    # Delegate to run_world.py
    sys.argv[0] = "scripts/run_world.py"
    run_world_path = ROOT / "scripts" / "run_world.py"
    code = run_world_path.read_text()
    exec(compile(code, str(run_world_path), "exec"), {"__name__": "__main__", "__file__": str(run_world_path)})
