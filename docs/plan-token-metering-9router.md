# Plan: Đo token của agent-team qua gateway 9router

> Tài liệu bổ sung cho [`plan-plugin-9router.md`](./plan-plugin-9router.md).
> Mục tiêu: tận dụng usage-tracking sẵn có của 9router để đo token **theo từng
> dev** và **theo từng task-ID**, không cần thêm tool đo bên ngoài (ccusage,
> toktrack…). Ưu điểm so với đọc log CLI: phủ **mọi** CLI kể cả DeepSeek, vì đo
> ngay tại cổng.

---

## 0. TL;DR

- 9router đã đo token mỗi request (thật từ provider; ước lượng khi free-tier).
- Lưu SQLite: **Usage History** (tổng hợp ngày), **Request Logs** (trạng thái),
  **Request Details** (full body + headers).
- Dashboard group được theo `rawModel`, `accountName`, `keyName`, `endpoint`.
- **Đòn bẩy chính:** mỗi dev một **API key riêng** → group theo `keyName` = token
  theo dev, không cần code.
- **Theo task-ID:** 9router không biết task của ta → join theo thời gian với
  `.claude/team/runs/*/meta.env` (mọi CLI), HOẶC nhúng header `x-task-id` —
  hybrid: dùng được cho **Claude Code + Codex**, DeepSeek/Gemini thì không (xem 3.2).

---

## 1. 9router đo token như thế nào (cơ sở)

| Hạng mục | Chi tiết |
|---|---|
| **Trích token thật** | Claude `input/output_tokens`; OpenAI `prompt/completion_tokens`; Gemini `usageMetadata`; Responses API `response.usage`. |
| **Ước lượng (fallback)** | Khi provider không trả usage (hay gặp ở tier free): `len(body)/4` cho input + buffer 2000, `len(content)/4` cho output. → *xấp xỉ*, không bằng hóa đơn. |
| **Lưu trữ (SQLite `~/.9router/db`)** | `saveRequestUsage` (Usage History, tổng hợp ngày) · `appendRequestLog` (nhật ký) · `saveRequestDetail` (full request/response + **headers**). |
| **Chiều group ở dashboard** | `rawModel`, `accountName`, `keyName`, `endpoint`. |
| **API** | `/api/usage/providers`, `/api/usage/request-details` (lọc theo provider + khoảng ngày). |

> Hệ quả: muốn tách số liệu theo "ai/việc gì", ta phải ánh xạ một trong các chiều
> trên (đặc biệt `keyName`) vào khái niệm dev/task của agent-team.

---

## 2. Đo theo DEV — qua `keyName` (cách chính)

### 2.1 Ý tưởng

Tạo **một API key cho mỗi dev** trong dashboard 9router, đặt tên `dev1…dev14`.
Mỗi `run_*.sh` của dev nào thì dùng key của dev đó. Group dashboard theo
`keyName` ⇒ token/chi phí tách sẵn theo dev. **Không cần viết code đo.**

### 2.2 Cấu hình

`.claude/bin/env.local.sh` (đã gitignore — xem mục 2.5 của plan gốc):

```sh
# Mỗi dev một key tạo sẵn trong dashboard 9router (Settings → API Keys)
NINEROUTER_KEY_DEV1=sk-9r-dev1-xxxx
NINEROUTER_KEY_DEV2=sk-9r-dev2-xxxx
NINEROUTER_KEY_DEV5=sk-9r-dev5-xxxx
# ... dev3,4,6,7,8,9,10,12,13,14
NINEROUTER_KEY=sk-9r-shared-xxxx     # fallback nếu dev chưa có key riêng
```

Trong `.claude/bin/_runner.sh`, sau khi đã xác định `$dev` (đoạn xử lý `--dev=`),
thêm:

```sh
if [ "${USE_9ROUTER:-0}" = "1" ]; then
  _kv="NINEROUTER_KEY_$(printf '%s' "$dev" | tr '[:lower:]' '[:upper:]')"  # NINEROUTER_KEY_DEV1
  _key="${!_kv:-${NINEROUTER_KEY:-}}"
  : "${NINEROUTER_HOST:=http://127.0.0.1:20128}"
  export ANTHROPIC_BASE_URL="$NINEROUTER_HOST/v1" ANTHROPIC_API_KEY="$_key"
  export OPENAI_BASE_URL="$NINEROUTER_HOST/v1"    OPENAI_API_KEY="$_key"
  # DeepSeek nếu CLI hỗ trợ base-url:
  export DEEPSEEK_BASE_URL="$NINEROUTER_HOST/v1"  DEEPSEEK_API_KEY="$_key"
fi
```

> Tận dụng đúng pattern `*_DEV<N>` mà repo đã dùng cho `CODEX_FLAGS_DEV*`.
> Vì các biến `*_API_KEY`/`*_BASE_URL` không nằm trong danh sách `unset` của
> `_runner.sh`, chúng sẽ truyền xuống CLI con bình thường.

### 2.3 Xem kết quả

Dashboard → **Usage** → group by `keyName`. Hoặc group by `rawModel` để xem
token theo model/combo. "Recent Requests" cho biết request thành công/lỗi.

---

## 3. Đo theo TASK-ID (T-001…)

9router **không** biết task-ID của agent-team. Hai cách lấy về mức task:

### 3.1 Join theo thời gian (khuyến nghị — không phụ thuộc CLI)

Mỗi run đã ghi `started_epoch` / `ended_at` / `dev` / `task_id` trong
`.claude/team/runs/<run-id>/meta.env`. Viết script đọc các file đó, gọi Usage API
của 9router lọc theo **key của dev + khoảng thời gian của run**, cộng token, rồi
ghi ngược `tokens_in` / `tokens_out` / `cost_est` vào chính `meta.env`.

Script gợi ý `.claude/bin/token-report.sh` (phác thảo):

```sh
#!/usr/bin/env bash
# Gắn token (đo bởi 9router) vào từng run dựa trên dev + khoảng thời gian.
set -euo pipefail
HOST="${NINEROUTER_HOST:-http://127.0.0.1:20128}"
for meta in .claude/team/runs/*/meta.env; do
  dev=$(grep -E '^dev=' "$meta" | cut -d= -f2-)
  task=$(grep -E '^task_id=' "$meta" | cut -d= -f2- || true)
  start=$(grep -E '^started_epoch=' "$meta" | cut -d= -f2-)
  end=$(grep -E '^ended_at=' "$meta" | cut -d= -f2- || echo "")
  # Gọi API usage (điều chỉnh tham số filter theo /api/usage thật của bản 9router)
  # Ví dụ: lọc theo keyName=<dev> và from/to = start..end, tổng prompt/completion.
  resp=$(curl -fsS "$HOST/api/usage/request-details?keyName=$dev&from=$start&to=$end" \
           -H "Authorization: Bearer ${NINEROUTER_KEY:-}" || echo '{}')
  tin=$(printf '%s' "$resp"  | jq '[.items[]?.prompt_tokens]     | add // 0')
  tout=$(printf '%s' "$resp" | jq '[.items[]?.completion_tokens] | add // 0')
  { echo "tokens_in=$tin"; echo "tokens_out=$tout"; } >> "$meta"
  echo "$task ($dev): in=$tin out=$tout"
done
```

> ⚠️ Tên tham số API (`keyName`, `from`, `to`) và hình dạng JSON (`.items[]`,
> `prompt_tokens`) **phải kiểm chứng** với bản 9router thật — DeepWiki mới chỉ
> xác nhận có endpoint `/api/usage/request-details` lọc theo provider + ngày.
> Nếu API không đủ filter, đọc thẳng SQLite (`~/.9router/db/...sqlite`) bằng SQL.

### 3.2 Nhúng header `x-task-id` (chính xác hơn — HYBRID theo CLI)

9router lưu **headers** trong Request Details. Nếu CLI cho phép gắn header tùy ý,
đặt `x-task-id: <T-id>` mỗi run → mỗi request gắn cứng task-ID, khỏi join mờ theo
thời gian.

**Kết quả kiểm tra khả năng inject header của từng CLI** (đã tra tài liệu, 2026-06):

| CLI (dev) | Inject header tùy ý? | Cơ chế |
|---|---|---|
| **Claude Code** (dev5/6/7/8/9/14) | ✅ Có | Biến env `ANTHROPIC_CUSTOM_HEADERS` (`Header: value`, nhiều header cách nhau bằng newline/phẩy); hoặc `.claude/settings.json`. LiteLLM dùng chính cơ chế này để gán chi phí → áp lên request model thật. |
| **Codex** (dev1/2/12/13) | ✅ Có (qua `config.toml`) | `http_headers` (cố định) hoặc `env_http_headers` (đọc từ biến env) trong `model_providers`. Cần provider trỏ 9router, `wire_api = "responses"`. |
| **DeepSeek** (dev3/4/10) | ⚠️ Chưa xác nhận / nhiều khả năng không | Chỉ thấy `base_url`/key + MCP config; không thấy tùy chọn header tùy ý cho request model. → Dùng **3.1** (join theo thời gian). |
| **Gemini** (dev11) | ❌ Không (cho request model) | `-H/--header`/`headers` chỉ áp cho **MCP server**, không phải call model. Vả lại dev11 **không** route qua 9router (rủi ro ban) → bỏ qua. |

**→ Chiến lược HYBRID:** dùng header `x-task-id` cho **Claude Code + Codex**
(8/13 dev đi qua 9router); **DeepSeek dùng 3.1**; Gemini không liên quan.

Đặt trong `_runner.sh`, cùng chỗ chọn key ở mục 2.2:

```sh
# --- Claude (haiku/sonnet/opus devs) ---
if [ "${USE_9ROUTER:-0}" = "1" ]; then
  export ANTHROPIC_CUSTOM_HEADERS="x-task-id: ${task_id:-none}"
fi

# --- Codex (dev1/2/12/13) ---
# 1) Một lần, trong ~/.codex/config.toml:
#      [model_providers.ninerouter]
#      base_url = "http://127.0.0.1:20128/v1"
#      wire_api = "responses"
#      env_http_headers = { "x-task-id" = "CODEX_TASK_ID" }
# 2) Mỗi run: export biến mà env_http_headers trỏ tới:
if [ "${USE_9ROUTER:-0}" = "1" ]; then
  export CODEX_TASK_ID="${task_id:-none}"
fi

# --- DeepSeek (dev3/4/10): KHÔNG có header → để 3.1 (join thời gian) lo ---
```

**Lưu ý kiểm chứng trước khi tin số liệu:**
- Với Claude Code có báo lỗi header *không được forward* — nhưng đó là header cho
  **MCP**, không phải request model, nên trường hợp này không bị ảnh hưởng.
- Dù đã xác nhận qua tài liệu, vẫn nên **gửi 1 request thử rồi mở 9router →
  Request Details** xem `x-task-id` có thực sự xuất hiện trong headers không, cho
  từng CLI, trước khi dựa vào số liệu.

---

## 4. Đưa số liệu vào quy trình agent-team

- **Run diary của leader:** sau mỗi batch, chạy `token-report.sh` rồi để leader
  đính kèm bảng "token theo dev/task" vào `.claude/team/runs/leader-<TS>.md`.
- **Memory vault:** dev10 (memory scribe) có thể ghi note `features/` hoặc một
  ghi chú chi phí định kỳ, link tới run tương ứng.
- **Cảnh báo ngân sách:** ngưỡng đơn giản trong `token-report.sh` (vd tổng cost
  ước lượng > X thì in WARNING) — vì 9router đã có cost estimation theo model.

---

## 5. Hạn chế & lưu ý

- **Free-tier = ước lượng:** token tier free là `len/4 + buffer`, lệch so với
  thật. Dùng để **so sánh tương đối** giữa dev/model là ổn; đừng coi là hóa đơn.
- **Phụ thuộc proxy:** chỉ đo được request *đi qua* 9router. Dev nào còn gọi
  thẳng provider (vd dev11/Gemini — cố tình không route, xem plan gốc) sẽ **không**
  xuất hiện trong số liệu 9router; đo riêng bằng ccusage/Gemini nếu cần.
- **API/SQLite schema cần xác minh:** chốt tên tham số filter và cột DB theo bản
  9router thật trước khi tin số liệu script.
- **Giới hạn số API key:** xác nhận 9router cho tạo đủ nhiều key đặt tên (≥14).
  Nếu không, gộp theo *nhóm* (vd theo CLI: codex/claude/deepseek) thay vì từng dev.
- **Bảo mật:** key để trong `env.local.sh` đã gitignore; không commit.

---

## 6. Checklist triển khai

1. [ ] Dashboard 9router → tạo key `dev1…dev14` (hoặc theo nhóm CLI).
2. [ ] Thêm key vào `env.local.sh`; patch `_runner.sh` chọn key theo `$dev` (2.2).
3. [ ] Chạy 1 batch test → dashboard group by `keyName` thấy tách theo dev.
4. [ ] Viết `token-report.sh`, xác minh tham số `/api/usage` thật (3.1).
5. [ ] Cho leader đính bảng token vào run diary (4).
6. [ ] (Tùy chọn) Bật header `x-task-id` cho Claude Code + Codex; gửi 1 request
       thử → kiểm tra header hiện trong 9router Request Details (3.2). DeepSeek
       để 3.1 lo.

---

*Tài liệu này chưa thay đổi code. Bước đầu tiên đụng repo: tạo key trong 9router
+ patch `_runner.sh` theo mục 2.2.*
