#!/usr/bin/env bash
# status.sh — show status of all 3 seeds at a glance.

set -euo pipefail

for SEED_IDX in 1 2 3; do
    WORKDIR="$HOME/Desktop/agentopia_runs/seed${SEED_IDX}"
    echo "=== seed${SEED_IDX} ==="

    if [ ! -d "$WORKDIR" ]; then
        echo "  workdir: not created"
        echo ""
        continue
    fi

    PID_FILE=$(ls -t "$WORKDIR/logs/"seed${SEED_IDX}_*.pid 2>/dev/null | head -1 || echo "")
    if [ -z "$PID_FILE" ]; then
        echo "  status: never launched"
    else
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            STATE=$(ps -o state= -p "$PID" 2>/dev/null | tr -d ' ' || echo "?")
            case "$STATE" in
                T*) HUMAN="PAUSED (SIGSTOP'd)" ;;
                R*|S*|U*|I*) HUMAN="RUNNING" ;;
                *) HUMAN="state=$STATE" ;;
            esac
            echo "  status: $HUMAN  PID=$PID"
        else
            echo "  status: EXITED (stale pid file: $PID_FILE)"
        fi
    fi

    # Latest usage file
    USAGE_FILE=$(ls -t "$WORKDIR/logs/"*_usage.jsonl 2>/dev/null | head -1 || echo "")
    if [ -n "$USAGE_FILE" ]; then
        NCALLS=$(wc -l < "$USAGE_FILE" | tr -d ' ')
        # Sum prompt + completion via python (avoid sed/awk per env policy)
        python3 -c "
import json
total=0; prompt=0; completion=0
try:
    with open('$USAGE_FILE') as f:
        for line in f:
            try:
                e=json.loads(line)
                prompt += e.get('prompt',0) or 0
                completion += e.get('completion',0) or 0
            except: pass
total = prompt + completion
print(f'  calls: $NCALLS | in: {prompt/1e6:.2f}M out: {completion/1e6:.2f}M total: {total/1e6:.2f}M')
" 2>/dev/null || echo "  calls: $NCALLS (sum failed)"
    fi

    # Latest log tail
    LOG_FILE=$(ls -t "$WORKDIR/logs/"*.log 2>/dev/null | head -1 || echo "")
    if [ -n "$LOG_FILE" ]; then
        LAST=$(tail -1 "$LOG_FILE" 2>/dev/null | head -c 200 || echo "")
        echo "  last log: $LAST"
    fi
    echo ""
done
