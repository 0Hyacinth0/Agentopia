#!/usr/bin/env bash
# launch_seed.sh — launch one Agentopia seed in its isolated workdir
#
# Per策略 A' + OSF pre-registration:
#   - 100 agents × 3 years × 10 weeks × 5 days
#   - god_model = role_model = ark-code-latest (glm-5.2)
#   - temperature = 0.7, max_concurrency = 5
#   - 3 independent seed values (committed 2026-06-24, from secrets.randbelow):
#       seed1 = 3134974641
#       seed2 = 3966574521
#       seed3 = 3146675649
#     (Note: Agentopia source has no RNG seed control. Per supplementary
#     clarification, these values serve as run identifiers in the data path
#     and git tag, not as deterministic RNG seeds. Trajectory variance
#     across runs derives from glm-5.2 sampling stochasticity.)
#
# Usage:
#   source ~/.hermes/agentopia.env
#   ./launch_seed.sh <seed_idx 1|2|3>
#
# Routes to the matching ARK_KEY_<N> from the env file.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <seed_idx 1|2|3>"
    echo "  Requires: source ~/.hermes/agentopia.env  first"
    exit 1
fi

SEED_IDX="$1"
case "$SEED_IDX" in
    1) SEED_VALUE=3134974641; KEY_VAR=ARK_KEY_1 ;;
    2) SEED_VALUE=3966574521; KEY_VAR=ARK_KEY_2 ;;
    3) SEED_VALUE=3146675649; KEY_VAR=ARK_KEY_3 ;;
    *) echo "ERROR: seed_idx must be 1, 2, or 3"; exit 1 ;;
esac

# Resolve the api key by variable name
ARK_KEY="${!KEY_VAR:-}"
ARK_BASE_URL="${ARK_BASE_URL:-https://ark.cn-beijing.volces.com/api/coding/v3}"
ARK_MODEL="${ARK_MODEL:-ark-code-latest}"

if [ -z "$ARK_KEY" ] || [[ "$ARK_KEY" == *"fillme"* ]] || [[ "$ARK_KEY" == *"xxx"* ]]; then
    echo "ERROR: $KEY_VAR is not set or is still a placeholder."
    echo "       Edit ~/.hermes/agentopia.env and 'source' it before running."
    exit 1
fi

WORKDIR="$HOME/Desktop/agentopia_runs/seed${SEED_IDX}"
MAIN_REPO="$HOME/Desktop/agentopia"

# Ensure workdir exists
if [ ! -d "$WORKDIR" ]; then
    "$MAIN_REPO/scripts/setup_seed_workdir.sh" "$SEED_IDX"
fi

cd "$WORKDIR"
source .venv/bin/activate

# run_id MUST be 8-digit MMDDHHMM (Agentopia run_manager.py:18 enforces this).
# We embed the seed_idx via the data dir name suffix logged separately, and
# use the canonical timestamp run_id for Agentopia compatibility.
RUN_ID="$(date +%m%d%H%M)"
RUN_TAG="seed${SEED_IDX}_${SEED_VALUE}_${RUN_ID}"   # used in our logs/usage filename

LOG_FILE="$WORKDIR/logs/${RUN_TAG}.log"
USAGE_FILE="$WORKDIR/logs/${RUN_TAG}_usage.jsonl"

# Materialize per-seed config
CONFIG_PATH="$WORKDIR/config.json"
python3 - <<PYEOF
import json, copy
base = json.load(open("$MAIN_REPO/config.json"))
cfg = copy.deepcopy(base)

# OSF-frozen parameters (override config.json defaults if drifted)
cfg["world"]["name"] = "apartment"
cfg["world"]["language"] = "en"
cfg["world"]["time"]["n_year"] = 3
cfg["world"]["time"]["n_week"] = 10
cfg["world"]["time"]["n_day"] = 5
cfg["world"]["time"]["n_contact_slot"] = 5
cfg["world"]["contact"]["n_action_per_slot"] = 10
cfg["max_concurrency"] = 5
cfg["temperature"] = 0.7

# Per-account key (do not write the key into git-tracked main config.json)
cfg["models"]["ark-code"]["api_key"] = "${ARK_KEY}"
cfg["models"]["ark-code"]["url"] = "${ARK_BASE_URL}"
cfg["models"]["ark-code"]["vllm_model_name"] = "${ARK_MODEL}"

json.dump(cfg, open("$CONFIG_PATH", "w"), indent=2, ensure_ascii=False)
print(f"[launch] config materialized -> $CONFIG_PATH")
PYEOF

# token_usage.jsonl is hardcoded path in run_with_monitor.py — symlink it per-seed
rm -f "$WORKDIR/token_usage.jsonl"
ln -sf "$USAGE_FILE" "$WORKDIR/token_usage.jsonl"

echo "[launch] ============================================"
echo "[launch] seed_idx:    $SEED_IDX"
echo "[launch] seed_value:  $SEED_VALUE"
echo "[launch] key_var:     $KEY_VAR (${ARK_KEY:0:12}...)"
echo "[launch] workdir:     $WORKDIR"
echo "[launch] run_id:      $RUN_ID"
echo "[launch] run_tag:     $RUN_TAG"
echo "[launch] log file:    $LOG_FILE"
echo "[launch] usage file:  $USAGE_FILE"
echo "[launch] config:      apartment, 100 agents, 3y × 10w × 5d"
echo "[launch] ============================================"
echo "[launch] starting in 3 seconds, Ctrl+C to abort..."
sleep 3

# Launch
python3 scripts/run_with_monitor.py \
    --world apartment \
    --max-agents 100 \
    --years 3 \
    --weeks 10 \
    --run-id "$RUN_ID" \
    > "$LOG_FILE" 2>&1 &

PID=$!
echo "[launch] PID=$PID, detached. Tail with: tail -f $LOG_FILE"
echo "$PID" > "$WORKDIR/logs/${RUN_TAG}.pid"
echo "[launch] PID file: $WORKDIR/logs/${RUN_TAG}.pid"

disown $PID
