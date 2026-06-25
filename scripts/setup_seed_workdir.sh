#!/usr/bin/env bash
# setup_seed_workdir.sh — create an isolated workdir for one seed
#
# Each seed runs in its own directory under ~/Desktop/agentopia_runs/seed{N}/,
# with .venv, src, scripts, data/apartment symlinked from the main repo to save
# disk and keep code in one place. data/<runid>/ (the per-run output dir) lives
# inside the workdir, fully isolated. config.json and token_usage.jsonl are
# materialized per-workdir so 3 parallel processes don't collide.
#
# Usage:
#   ./setup_seed_workdir.sh <seed_idx>
#
# This is idempotent — re-runs are safe.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <seed_idx 1|2|3>"
    exit 1
fi

SEED_IDX="$1"
case "$SEED_IDX" in
    1|2|3) ;;
    *) echo "ERROR: seed_idx must be 1, 2, or 3"; exit 1 ;;
esac

MAIN_REPO="$HOME/Desktop/agentopia"
WORKDIR="$HOME/Desktop/agentopia_runs/seed${SEED_IDX}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Symlink shared (code, venv, base persona data)
ln -sfn "$MAIN_REPO/.venv" .venv
ln -sfn "$MAIN_REPO/src" src
ln -sfn "$MAIN_REPO/scripts" scripts
ln -sfn "$MAIN_REPO/requirements.txt" requirements.txt

# data/ needs to be local because Agentopia writes data/apartment_<runid>/ here.
# But the base data/apartment/ persona files should be shared.
mkdir -p data
ln -sfn "$MAIN_REPO/data/apartment" data/apartment

# logs dir local
mkdir -p logs

echo "[setup] seed${SEED_IDX} workdir ready: $WORKDIR"
echo "[setup] code/venv symlinked from: $MAIN_REPO"
echo "[setup] data/apartment (personas) symlinked"
echo "[setup] data/apartment_<runid>/ will be written locally"
