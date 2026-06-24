# Plan: Plug 9router vào agent-team

> Kế hoạch kỹ thuật — dựa trên cấu trúc thật của repo (`.claude/bin/env.sh`,
> `_runner.sh`, các `run_*.sh`). Mục tiêu: cho toàn bộ 14 dev đi qua 9router để
> **tiết kiệm token (RTK)** và **fallback khi hết quota**, mà **không** đổi logic
> điều phối của leader và **giữ được đường lui** về hành vi cũ.

---

## 0. TL;DR

- Điểm chèn duy nhất, sạch nhất: **`env.sh`** export các biến `*_BASE_URL`.
  `_runner.sh` source `env.sh` và chỉ `unset` `*_FLAGS`/`*_BIN` — **không** đụng
  tới `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`… nên các biến này sống sót và tới
  được mọi CLI con. → Không phải sửa từng `run_*.sh`.
- Bật/tắt bằng 1 cờ `USE_9ROUTER` (mặc định `0` = chạy y như hiện tại).
- Thêm health-check 9router vào `team-doctor.sh`.
- Không động vào memory vault — 9router không thay thế nó.

---

## 1. Hiểu cơ chế hiện tại (cơ sở của plan)

Luồng gọi CLI (xác minh trong `_runner.sh`):

1. `run_<cli>.sh` → `source _runner.sh` → `runner_exec "<cli>" "<bin>" "<FLAGS_VAR>" "$@"`.
2. `_runner.sh` `unset` các `*_FLAGS`/`*_BIN` rồi `source env.sh` (chống rò flag cũ).
3. Cuối cùng chạy: `$bin_spec $flags "$full_prompt"` (dòng ~203).

→ Hệ quả quan trọng: **mọi biến môi trường export trong `env.sh` mà không nằm
trong danh sách `unset` sẽ truyền xuống CLI con.** Các CLI (Claude/Codex/Gemini/
DeepSeek) đều đọc base-url qua env var → ta chỉ cần export đúng biến ở `env.sh`.

Mapping base-url theo CLI:

| Dev | CLI | Biến base-url | Biến key |
|---|---|---|---|
| dev5/6/7/8/9/14 | Claude | `ANTHROPIC_BASE_URL` | `ANTHROPIC_API_KEY` |
| dev1/2/12/13 | Codex | `OPENAI_BASE_URL` | `OPENAI_API_KEY` |
| dev3/4/10 | DeepSeek | base-url OpenAI-compatible (tùy CLI) | `DEEPSEEK_API_KEY` |
| dev11 | Gemini | (xem mục Rủi ro — **không** nên route) | — |

> Tên biến chính xác cho DeepSeek/Codex cần xác nhận lại theo phiên bản CLI bạn
> đang dùng (`--help`). Plan dùng tên phổ biến nhất làm mặc định.

---

## 2. Thay đổi đề xuất (theo file)

### 2.1 `.claude/bin/env.sh` — thêm khối 9router (đầu file, trước phần CLI)

```sh
# ---- 9router gateway (OPTIONAL) -------------------------------------------
# Khi USE_9ROUTER=1, mọi CLI con sẽ trỏ base-url về proxy 9router thay vì gọi
# thẳng provider. Lợi ích: RTK -20..40% token + fallback 3 tầng khi hết quota.
# Dùng 127.0.0.1 (KHÔNG dùng localhost) để tránh lỗi resolve IPv6.
: "${USE_9ROUTER:=0}"
: "${NINEROUTER_HOST:=http://127.0.0.1:20128}"
: "${NINEROUTER_KEY:=}"          # API key local lấy từ dashboard 9router

if [ "$USE_9ROUTER" = "1" ]; then
  : "${ANTHROPIC_BASE_URL:=$NINEROUTER_HOST/v1}"
  : "${ANTHROPIC_API_KEY:=$NINEROUTER_KEY}"
  : "${OPENAI_BASE_URL:=$NINEROUTER_HOST/v1}"
  : "${OPENAI_API_KEY:=$NINEROUTER_KEY}"
  : "${DEEPSEEK_BASE_URL:=$NINEROUTER_HOST/v1}"   # nếu DeepSeek CLI hỗ trợ
  : "${DEEPSEEK_API_KEY:=$NINEROUTER_KEY}"
  export ANTHROPIC_BASE_URL ANTHROPIC_API_KEY \
         OPENAI_BASE_URL OPENAI_API_KEY \
         DEEPSEEK_BASE_URL DEEPSEEK_API_KEY
fi
# ---------------------------------------------------------------------------
```

> Vì dùng `:=` (chỉ gán khi chưa set), ai muốn override per-shell vẫn được.
> `USE_9ROUTER=0` mặc định ⇒ commit này **không đổi hành vi hiện tại**.

### 2.2 (Tùy chọn) Chọn model/combo của 9router theo dev

9router định danh model bằng prefix (`cc/`, `cx/`, `glm/`, `kr/`…). Hai hướng:

- **Hướng A — đơn giản:** không đổi model trong agent-team; tạo *alias/combo*
  trong dashboard 9router trùng tên model mà CLI đang gửi (vd map `opus` →
  combo `cc/claude-opus → glm/glm-5.1 → kr/...`). Ưu điểm: **không sửa code thêm**.
- **Hướng B — tường minh:** sửa `OPUS_BIN`/`CODEX_FLAGS_*` để truyền thẳng tên
  combo. Vd Codex: thêm `-c model="cx/gpt-5.5"`. Ưu điểm: rõ ràng; nhược: phải
  giữ đồng bộ với env.sh.

→ Khuyến nghị **Hướng A** cho lần đầu (ít rủi ro nhất).

### 2.3 `.claude/bin/team-doctor.sh` — thêm pre-flight check

```sh
if [ "${USE_9ROUTER:-0}" = "1" ]; then
  if curl -fsS "${NINEROUTER_HOST:-http://127.0.0.1:20128}/v1/models" >/dev/null 2>&1; then
    echo "OK   9router reachable at $NINEROUTER_HOST"
  else
    echo "FAIL 9router bật (USE_9ROUTER=1) nhưng không gọi được $NINEROUTER_HOST"
    echo "     -> khởi động 9router, hoặc đặt USE_9ROUTER=0 để bỏ qua proxy"
  fi
fi
```

→ Chặn được lỗi "cả team chết vì proxy chưa chạy" trước khi `spawn-team.sh`.

### 2.4 `_runner.sh` — KHÔNG cần sửa logic

Chỉ cần đảm bảo khối env 9router **không bị `unset`**. Hiện `unset` chỉ liệt kê
`*_FLAGS`/`*_BIN`, nên các `*_BASE_URL`/`*_API_KEY` an toàn. (Ghi 1 comment nhắc
để người sau không vô tình thêm chúng vào danh sách unset.)

### 2.5 `.gitignore` — không commit key

Đảm bảo không commit `NINEROUTER_KEY`. Cách an toàn: để key ở file env riêng đã
gitignore (vd `.claude/bin/env.local.sh`) và cho `env.sh` source nếu tồn tại:

```sh
_local="$( cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd )/env.local.sh"
[ -f "$_local" ] && source "$_local"
```

---

## 3. Cải thiện kiến trúc đi kèm (nên làm cùng lúc)

Plug 9router là dịp tốt để vá vài điểm của agent-team:

1. **Quan sát chi phí theo dev:** ghi thêm field `provider`/`model_used` vào
   `meta.env` của mỗi run (đọc từ header phản hồi 9router nếu có), để run diary
   của leader đối chiếu với dashboard 9router → biết dev nào đốt token nhất.
2. **Degraded-aware fallback:** `_runner.sh` đã phân biệt
   `done/partial/degraded/failed`. Khi `USE_9ROUTER=1`, một `failed` do hết quota
   sẽ hiếm hơn (9router tự rớt tier) → cập nhật ghi chú trong `leader.md` rằng
   `failed` giờ thiên về lỗi logic chứ không phải quota.
3. **Đường lui rõ ràng:** tài liệu hóa `USE_9ROUTER=0` như "kill switch" trong
   README + `team-doctor.sh`. Khi proxy có sự cố, một biến là quay lại bình thường.
4. **Không đụng memory vault:** giữ nguyên `.claude/memory/`. 9router không chia
   sẻ ngữ cảnh giữa dev; share memory vẫn do leader/dev đọc-ghi vault rồi nhét
   vào prompt. Ghi rõ ranh giới này vào README để tránh hiểu nhầm về sau.

---

## 4. Rủi ro & quyết định cần chốt

- **Gemini (dev11):** theo README 9router, dùng Gemini *free* với tool không phải
  Gemini **có thể bị ban account**. → **Không** route dev11 qua 9router; để
  `GEMINI_*` gọi thẳng như hiện tại. (Khối env 9router ở trên cố tình không set
  biến Gemini.)
- **ToS subscription:** đẩy tài khoản trả phí (Claude/Codex) qua proxy bên thứ ba
  có thể vi phạm điều khoản. Cân nhắc chỉ route qua tier free/cheap, hoặc dùng
  account phụ. → *Quyết định của bạn.*
- **Single point of failure:** mọi dev qua 1 proxy. Bù lại bằng health-check
  (2.3) + kill switch (3.3).
- **Tên model/combo & biến env theo CLI:** phải xác nhận theo phiên bản CLI thật
  (`GET /v1/models` của 9router cho danh sách model; `<cli> --help` cho tên biến).
- **Auth đã có sẵn:** auth CLI hiện tại nằm trong config riêng của từng CLI;
  9router cần bạn *connect lại* các account đó trong dashboard của nó thì mới
  route được. Đây là việc setup thủ công 1 lần, không tự kế thừa.

---

## 5. Lộ trình thực thi (từng bước, có thể dừng bất cứ đâu)

1. **Cài & chạy 9router** (`npm i -g 9router` → `9router`), connect 1 provider
   free (Kiro/OpenCode) trong dashboard, lấy API key local.
2. **PoC 1 dev:** đặt `USE_9ROUTER=1` + `NINEROUTER_KEY=...` ở shell, chạy *một*
   task M qua dev1 (codex). Xác nhận request hiện trong dashboard 9router.
3. **Đo:** so token/chi phí task đó (RTK on vs off) trên dashboard.
4. **Hợp nhất vào repo:** thêm khối env (2.1), env.local.sh + gitignore (2.5),
   health-check (2.3). Mặc định `USE_9ROUTER=0`.
5. **Tạo combo theo dev** trong dashboard 9router (Hướng A, 2.2).
6. **Chạy full team** với `USE_9ROUTER=1`, theo dõi `team-tui.sh` + dashboard.
7. **Tài liệu hóa** kill switch & ranh giới memory vào README.

---

## 6. Tiêu chí nghiệm thu

- `USE_9ROUTER=0`: team chạy y hệt trước (regression = 0).
- `USE_9ROUTER=1` + 9router tắt: `team-doctor.sh` báo FAIL rõ ràng, không spawn mù.
- `USE_9ROUTER=1` + 9router bật: ≥1 dev hoàn tất 1 task, request xuất hiện trong
  dashboard, token tiết kiệm > 0 nhờ RTK.
- Không có key nào bị commit vào git.

---

*Plan này chưa thay đổi code nào. Khi bạn duyệt, bước đầu tiên đụng repo là patch
`env.sh` (mục 2.1) + tạo `env.local.sh` (mục 2.5).*
