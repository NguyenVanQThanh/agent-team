#!/usr/bin/env bash
# token-report.sh — gắn số liệu token (đo bởi 9router) vào từng run của agent-team.
#
# Cách hoạt động:
#   1. Duyệt mọi .claude/team/runs/*/meta.env
#   2. Với mỗi run, gọi /api/usage/request-details của 9router,
#      lọc theo keyName=<dev> + khoảng thời gian started_epoch..ended_at
#   3. Cộng prompt_tokens + completion_tokens, ghi ngược vào meta.env:
#      tokens_in=, tokens_out=, cost_est=
#   4. In bảng tổng hợp theo dev + task
#
# Yêu cầu:
#   - USE_9ROUTER=1 và 9router đang chạy (hoặc env.local.sh set sẵn)
#   - curl + jq trên PATH
#   - NINEROUTER_HOST, NINEROUTER_KEY (hoặc per-dev key) đã set
#
# Usage:
#   .claude/bin/token-report.sh                  # tất cả runs
#   .claude/bin/token-report.sh --since=20260624 # chỉ runs trong ngày
#   .claude/bin/token-report.sh --run=<run-id>   # 1 run cụ thể
#   .claude/bin/token-report.sh --summary        # chỉ in bảng tổng, không patch meta.env
#
# ⚠️  Tên tham số API (keyName, from, to) và cấu trúc JSON (.items[].prompt_tokens)
#     phải xác minh với bản 9router thật. Xem phần VERIFY_API_SCHEMA bên dưới.

set -uo pipefail

SCRIPT_DIR="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )"
# Source env để lấy NINEROUTER_HOST, NINEROUTER_KEY, USE_9ROUTER
_env_file="$SCRIPT_DIR/env.sh"
[[ -f "$_env_file" ]] && source "$_env_file"

REPO="$( cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd )"
RUNS_DIR="$REPO/.claude/team/runs"
HOST="${NINEROUTER_HOST:-http://127.0.0.1:20128}"
AUTH_KEY="${NINEROUTER_KEY:-}"   # shared fallback; per-dev key được chọn bên dưới

SINCE=""
TARGET_RUN=""
SUMMARY_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --since=*)    SINCE="${arg#--since=}" ;;
    --run=*)      TARGET_RUN="${arg#--run=}" ;;
    --summary)    SUMMARY_ONLY=1 ;;
    -h|--help)
      grep '^#' "$0" | head -30 | sed 's/^# \?//'
      exit 0 ;;
    *) echo "error: unknown arg '$arg'" >&2; exit 2 ;;
  esac
done

# ---- pre-flight ----

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl required" >&2; exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq required" >&2; exit 2
fi
if [[ "${USE_9ROUTER:-0}" != "1" ]]; then
  echo "warning: USE_9ROUTER ≠ 1; số liệu sẽ rỗng (gọi thẳng provider, không qua 9router)" >&2
fi
if ! curl -fsS "$HOST/v1/models" -H "Authorization: Bearer $AUTH_KEY" >/dev/null 2>&1; then
  echo "error: không gọi được 9router tại $HOST" >&2
  echo "       Kiểm tra USE_9ROUTER=1, 9router đang chạy, NINEROUTER_HOST đúng" >&2
  exit 1
fi

# ---- VERIFY_API_SCHEMA (uncomment để test endpoint thật) ----
# curl -fsS "$HOST/api/usage/request-details?limit=1" \
#   -H "Authorization: Bearer $AUTH_KEY" | jq . | head -40
# exit 0

# ---- hàm gọi API + tính token ----

_dev_key() {
  # Trả về key cho dev (per-dev nếu có, fallback shared)
  local dev="$1"
  local dev_up; dev_up="$(printf '%s' "$dev" | tr '[:lower:]' '[:upper:]')"
  local kvar="NINEROUTER_KEY_${dev_up}"
  echo "${!kvar:-$AUTH_KEY}"
}

_epoch_to_iso() {
  # Chuyển unix epoch → ISO8601 (fallback nếu date -d không dùng được)
  local ep="$1"
  date -d "@$ep" -Iseconds 2>/dev/null \
    || date -r "$ep" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null \
    || echo "$ep"
}

_fetch_usage() {
  # Args: <dev> <task_id_or_empty> <start_epoch> <end_iso_or_empty>
  #
  # Chiến lược HYBRID (§3.2):
  #   - Claude/Codex devs: filter theo x-task-id header nếu task_id có sẵn
  #     (chính xác hơn join thời gian). Param: taskId=<T-xxx>
  #   - DeepSeek devs (dev3/4/10): không inject header → filter theo thời gian (§3.1)
  #   - Fallback: luôn filter keyName+thời gian nếu taskId filter không được hỗ trợ
  # ⚠️  Tên param (taskId vs task_id vs x-task-id) cần xác minh với API thật.
  local dev="$1" task_id="$2" start="$3" end="$4"
  local key; key="$(_dev_key "$dev")"
  local start_iso; start_iso="$(_epoch_to_iso "$start")"

  # Chọn strategy theo CLI của dev
  local use_task_header=0
  case "$dev" in
    dev1|dev2|dev5|dev6|dev7|dev8|dev9|dev12|dev13|dev14) use_task_header=1 ;;
  esac

  local params="keyName=${dev}&from=${start_iso}"
  [[ -n "$end" ]] && params="${params}&to=${end}"
  # Thêm filter task-id khi CLI hỗ trợ inject header (Claude + Codex)
  if [[ "$use_task_header" = "1" && -n "$task_id" && "$task_id" != "none" ]]; then
    params="${params}&taskId=${task_id}"
  fi

  curl -fsS "${HOST}/api/usage/request-details?${params}" \
    -H "Authorization: Bearer $key" 2>/dev/null || echo '{}'
}

_sum_tokens() {
  # Đọc JSON, cộng prompt_tokens + completion_tokens theo .items[]
  # ⚠️  Tên field cần xác minh với bản 9router thật
  local json="$1"
  local tin tout
  tin=$(printf '%s' "$json"  | jq '[.items[]?.prompt_tokens     // .items[]?.input_tokens  // 0] | add // 0' 2>/dev/null || echo 0)
  tout=$(printf '%s' "$json" | jq '[.items[]?.completion_tokens // .items[]?.output_tokens // 0] | add // 0' 2>/dev/null || echo 0)
  echo "$tin $tout"
}

# ---- duyệt runs ----

declare -A DEV_TOTAL_IN=() DEV_TOTAL_OUT=()
declare -A TASK_TOTAL_IN=() TASK_TOTAL_OUT=()
patched=0 skipped=0

process_meta() {
  local meta="$1"
  local run_dir; run_dir="$(dirname "$meta")"
  local run_id; run_id="$(basename "$run_dir")"

  # đã có token → bỏ qua (trừ khi --summary)
  if grep -q '^tokens_in=' "$meta" 2>/dev/null && (( SUMMARY_ONLY == 0 )); then
    skipped=$((skipped+1)); return
  fi

  local dev task start end
  dev=$(grep -E '^dev=' "$meta" | head -1 | cut -d= -f2- | tr -d '\r')
  task=$(grep -E '^task_id=' "$meta" | head -1 | cut -d= -f2- | tr -d '\r' || true)
  start=$(grep -E '^started_epoch=' "$meta" | head -1 | cut -d= -f2- | tr -d '\r' || true)
  end=$(grep -E '^ended_at=' "$meta" | head -1 | cut -d= -f2- | tr -d '\r' || true)

  [[ -z "$dev" || -z "$start" ]] && return

  local json; json="$(_fetch_usage "$dev" "$task" "$start" "$end")"
  local tin tout; read -r tin tout <<< "$(_sum_tokens "$json")"

  if (( SUMMARY_ONLY == 0 )); then
    # patch meta.env — riêng dòng nếu chưa có, thay thế nếu có
    local tmpf; tmpf="$(mktemp)"
    grep -v -E '^tokens_in=|^tokens_out=' "$meta" > "$tmpf" || true
    { echo "tokens_in=$tin"; echo "tokens_out=$tout"; } >> "$tmpf"
    mv "$tmpf" "$meta"
    patched=$((patched+1))
  fi

  # tổng hợp per-dev
  DEV_TOTAL_IN["$dev"]=$(( ${DEV_TOTAL_IN["$dev"]:-0} + tin ))
  DEV_TOTAL_OUT["$dev"]=$(( ${DEV_TOTAL_OUT["$dev"]:-0} + tout ))
  # tổng hợp per-task
  if [[ -n "$task" ]]; then
    TASK_TOTAL_IN["$task"]=$(( ${TASK_TOTAL_IN["$task"]:-0} + tin ))
    TASK_TOTAL_OUT["$task"]=$(( ${TASK_TOTAL_OUT["$task"]:-0} + tout ))
  fi
  echo "  $run_id  dev=$dev  task=${task:-?}  in=$tin out=$tout"
}

echo ""
echo "======= token-report.sh — 9router usage ======="
echo "host: $HOST"
echo "runs: $RUNS_DIR"
echo ""

shopt -s nullglob
if [[ -n "$TARGET_RUN" ]]; then
  metas=( "$RUNS_DIR/$TARGET_RUN/meta.env" )
else
  metas=( "$RUNS_DIR"/*/meta.env )
fi
shopt -u nullglob

if (( ${#metas[@]} == 0 )); then
  echo "Không tìm thấy run nào trong $RUNS_DIR"
  exit 0
fi

for meta in "${metas[@]}"; do
  # lọc theo --since= nếu có
  if [[ -n "$SINCE" ]]; then
    run_ts="${meta#$RUNS_DIR/}"; run_ts="${run_ts:0:8}"  # YYYYMMDD từ run-id
    [[ "$run_ts" < "$SINCE" ]] && continue
  fi
  [[ -f "$meta" ]] && process_meta "$meta"
done

# ---- in bảng tổng hợp ----

echo ""
echo "------- Tổng hợp theo DEV -------"
printf "%-8s %12s %12s\n" "dev" "tokens_in" "tokens_out"
for dev in $(echo "${!DEV_TOTAL_IN[@]}" | tr ' ' '\n' | sort); do
  printf "%-8s %12s %12s\n" "$dev" "${DEV_TOTAL_IN[$dev]}" "${DEV_TOTAL_OUT[$dev]}"
done

echo ""
echo "------- Tổng hợp theo TASK -------"
printf "%-10s %12s %12s\n" "task" "tokens_in" "tokens_out"
for task in $(echo "${!TASK_TOTAL_IN[@]}" | tr ' ' '\n' | sort); do
  printf "%-10s %12s %12s\n" "$task" "${TASK_TOTAL_IN[$task]}" "${TASK_TOTAL_OUT[$task]}"
done

echo ""
if (( SUMMARY_ONLY == 0 )); then
  echo "patched: $patched run(s)  |  skipped (đã có): $skipped run(s)"
fi
echo "================================================"
