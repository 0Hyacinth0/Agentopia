#!/usr/bin/env bash
# stop_seed.sh — gracefully stop a seed process (lets Agentopia checkpoint).
#
# Usage:
#   ./stop_seed.sh 1
#
# After stop, you can resume later from the checkpoint with:
#   ./launch_seed.sh 1   # CAUTION: this creates a NEW run_id
# Or to resume the same run, manually:
#   cd ~/Desktop/agentopia_runs/seed1
#   source ~/.hermes/agentopia.env
#   python3 scripts/run_with_monitor.py --resume <data_dir> --max-agents 100

set -euo pipefail
SEED_IDX="$1"
WORKDIR="$HOME/Desktop/agentopia_runs/seed${SEED_IDX}"

PID_FILE=$(ls -t "$WORKDIR/logs/"seed${SEED_IDX}_*.pid 2>/dev/null | head -1 || echo "")
if [ -z "$PID_FILE" ]; then
    echo "ERROR: no pid file"
    exit 1
fi

PID=$(cat "$PID_FILE")
if ! kill -0 "$PID" 2>/dev/null; then
    echo "[stop] PID=$PID already not running"
    rm -f "$PID_FILE"
    exit 0
fi

echo "[stop] sending SIGTERM to seed${SEED_IDX} PID=$PID"
kill -TERM "$PID"

# Wait up to 60s for graceful exit (Agentopia atexit flush_all_caches takes time)
for i in {1..60}; do
    if ! kill -0 "$PID" 2>/dev/null; then
        echo "[stop] exited gracefully after ${i}s"
        rm -f "$PID_FILE"
        exit 0
    fi
    sleep 1
done

echo "[stop] still alive after 60s, sending SIGKILL"
kill -KILL "$PID" 2>/dev/null || true
rm -f "$PID_FILE"
