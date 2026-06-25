#!/usr/bin/env bash
# pause_seed.sh / resume_seed.sh — pause/resume one seed process
# (策略 A' 的"夜间跑 seed1"靠这个 + cron)
#
# Usage:
#   ./pause_seed.sh 1     # SIGSTOP — process frozen, releases nothing (Agentopia checkpoints automatically before key stages)
#   ./resume_seed.sh 1    # SIGCONT — process continues
#
# NOTE: pause via SIGSTOP is hard-pause (no graceful drain). For long-term
# stops, use ./stop_seed.sh which sends SIGTERM and lets Agentopia flush
# checkpoint, then re-launch later with --run-id <same id> to resume cleanly.

set -euo pipefail

ACTION="$1"   # pause | resume
SEED_IDX="$2"

WORKDIR="$HOME/Desktop/agentopia_runs/seed${SEED_IDX}"

PID_FILES=("$WORKDIR/logs/"seed${SEED_IDX}_*.pid)
if [ ! -e "${PID_FILES[0]}" ]; then
    echo "ERROR: no pid file under $WORKDIR/logs/"
    exit 1
fi

# Pick the most recent
PID_FILE=$(ls -t "$WORKDIR/logs/"seed${SEED_IDX}_*.pid | head -1)
PID=$(cat "$PID_FILE")

if ! kill -0 "$PID" 2>/dev/null; then
    echo "ERROR: process $PID not running"
    exit 1
fi

case "$ACTION" in
    pause)
        kill -STOP "$PID"
        echo "[paused] seed${SEED_IDX} PID=$PID SIGSTOP sent"
        ;;
    resume)
        kill -CONT "$PID"
        echo "[resumed] seed${SEED_IDX} PID=$PID SIGCONT sent"
        ;;
    *)
        echo "ERROR: action must be 'pause' or 'resume'"
        exit 1
        ;;
esac
