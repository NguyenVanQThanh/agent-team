# Ý tưởng: Kết hợp 9router + agent-team

> Bản ghi ý tưởng (design note). Mục tiêu: dùng **9router** làm tầng định tuyến model
> phía dưới, để **agent-team** chạy 14 dev song song mà tiết kiệm token và không
> bị "chết" giữa chừng vì hết quota.

---

## 1. Vì sao kết hợp

Hai dự án ở hai tầng khác nhau, không cạnh tranh:

- **agent-team** = tầng *điều phối* (leader chia task → spawn 14 CLI song song →
  memory vault). Nó quyết định *ai làm gì*.
- **9router** = tầng *ống dẫn model* (proxy local `:20128`, RTK nén token,
  fallback 3 tầng, đa provider). Nó quyết định *request đi tới model nào và tốn
  bao nhiêu*.

Mô hình 14 dev chạy đồng thời + tournament mode của agent-team **đốt rất nhiều
token** và dễ đụng rate-limit của một provider duy nhất. Đây đúng là bài toán
9router sinh ra để giải:

- **RTK** nén output tool (git diff, grep, ls, tree…) → giảm 20–40% input token
  *trên mỗi request của mỗi dev*. Càng nhiều dev, tiết kiệm tuyệt đối càng lớn.
- **Fallback 3 tầng** (Subscription → Cheap → Free): một dev hết quota Claude
  giữa batch sẽ tự rớt xuống GLM/MiniMax/Kiro thay vì fail cả task.
- **Đa account + auto-refresh token**: chia tải nhiều account cho nhiều dev chạy
  song song.
- **Quota tracking + usage analytics**: thấy được mỗi dev/CLI tốn bao nhiêu.

---

## 2. Kiến trúc sau khi tích hợp

```
  user (chat)
      │
      ▼
  [leader] (Opus subagent) ── viết tasks.md, spawn-team.sh
      │
      ▼
┌───────────────────────────────────────────────────────────┐
│ 14 dev CLI (codex / deepseek / haiku / sonnet / opus / gemini)
│ mỗi CLI trỏ base_url về 9router thay vì gọi thẳng provider
└───────────────────────────────────────────────────────────┘
      │  tất cả request đi qua...
      ▼
  ┌─────────────────────────────┐
  │  9router  (localhost:20128) │
  │  • RTK nén token            │
  │  • dịch format              │
  │  • fallback 3 tầng          │
  │  • quota / analytics        │
  └─────────────────────────────┘
      │
      ▼
  40+ providers / 100+ models
```

**Lưu ý quan trọng — phân tầng memory:**
9router **KHÔNG** chia sẻ ngữ cảnh giữa các dev. Việc share memory vẫn hoàn toàn
là của agent-team: leader/dev đọc-ghi `.claude/memory/` rồi nhét nội dung liên
quan vào prompt *trước khi* gửi. 9router chỉ chuyển tiếp cái prompt đó. Hai vai
trò không chồng lấn:

| Nhu cầu | Ai lo |
|---|---|
| Dev này thấy việc dev kia đã làm | agent-team — memory vault + status files |
| Giảm token / fallback / đa model cho từng request | 9router |

---

## 3. Điểm tích hợp cụ thể (trong repo agent-team)

Thay đổi tập trung ở `.claude/bin/`, không động vào logic điều phối của leader.

### 3.1 `.claude/bin/env.sh` — thêm endpoint chung

```sh
# 9router gateway (local proxy). Bật/tắt qua biến này.
export NINEROUTER_BASE="http://127.0.0.1:20128/v1"   # dùng 127.0.0.1, tránh IPv6
export NINEROUTER_KEY="<api-key-từ-dashboard-9router>"
export USE_9ROUTER="${USE_9ROUTER:-1}"               # 1 = route qua 9router
```

### 3.2 Các wrapper `run_*.sh` — trỏ base_url

Mỗi CLI có cách set base_url riêng; nguyên tắc: khi `USE_9ROUTER=1` thì ghi đè
endpoint + key.

```sh
# run_codex.sh (ví dụ)
if [ "$USE_9ROUTER" = "1" ]; then
  export OPENAI_BASE_URL="$NINEROUTER_BASE"
  export OPENAI_API_KEY="$NINEROUTER_KEY"
  # chọn model namespaced của 9router, ví dụ combo:
  CODEX_MODEL="${CODEX_MODEL:-cx/gpt-5.5}"
fi
```

```sh
# run_opus.sh / run_haiku.sh / run_sonnet.sh (Claude)
if [ "$USE_9ROUTER" = "1" ]; then
  export ANTHROPIC_BASE_URL="$NINEROUTER_BASE"
  export ANTHROPIC_API_KEY="$NINEROUTER_KEY"
fi
```

```sh
# run_gemini.sh / run_deepseek.sh: tương tự, dùng base_url OpenAI-compatible
```

### 3.3 Map dev → combo của 9router

Tận dụng "custom combo" của 9router để mỗi vai trò có một chuỗi fallback riêng,
khai báo một chỗ thay vì hard-code model trong từng wrapper:

| Dev | Vai trò | Combo gợi ý (tier 1 → 2 → 3) |
|---|---|---|
| dev5 / dev14 | senior / review (XL) | `cc/claude-opus` → `glm/glm-5.1` → `kr/claude-sonnet-4.5` |
| dev8 / dev9 | sonnet (L) | `cc/claude-sonnet` → `glm/glm-5.1` → `kr/...` |
| dev6 / dev7 | haiku (M, rẻ/nhanh) | `cc/claude-haiku` → `minimax/...` → `oc/...` |
| dev1/2/12/13 | codex | `cx/gpt-5.5` → `glm/...` → `oc/...` |
| dev11 | gemini research | `vertex/gemini-3-pro` → `oc/...` |

> Reasoning effort của Codex (low/medium/high/xhigh trong `env.sh`) vẫn giữ
> nguyên — đó là tham số phía CLI, độc lập với 9router.

---

## 4. Lợi ích kỳ vọng

- **Giảm chi phí token**: RTK cắt 20–40% input mỗi request × 14 dev × nhiều batch.
  Output dài (git diff, log) là thứ agent-team tạo ra liên tục → đúng "tủ" RTK.
- **Độ bền cao hơn**: một provider hết quota không làm fail cả batch; dev tự rớt
  xuống tier rẻ/free. Hợp với rule "luôn ≥ 2 dev mỗi spawn".
- **Quan sát được**: dashboard 9router cho thấy token/chi phí theo model — bổ
  sung cho run diary của leader.
- **Một chỗ đổi model**: muốn thử model mới cho cả team → sửa combo trong 9router,
  không phải sửa 9 wrapper.

---

## 5. Rủi ro & lưu ý

- **9router phải đang chạy** trước khi `spawn-team.sh`. Nên thêm health-check vào
  `team-doctor.sh`: `curl -fsS $NINEROUTER_BASE/models` trước khi cho phép run.
- **Single point of failure**: mọi dev đi qua một proxy → nếu 9router chết, cả
  team chết. Giữ `USE_9ROUTER=0` làm đường lui (gọi thẳng provider như cũ).
- **Provider free có điều kiện**: theo README 9router, một số tier free đã ngừng
  (iFlow, Qwen OAuth); và **dùng Gemini CLI free với tool không phải Gemini có
  thể bị ban account** — chỉ đưa Gemini vào combo của dev11 (gemini) cho an toàn.
- **Không trộn lẫn memory**: nhắc lại — 9router không thay thế memory vault. Đừng
  kỳ vọng dev "tự nhớ" nhờ proxy.
- **Bảo mật**: nếu deploy 9router ra ngoài localhost, bật `REQUIRE_API_KEY=true`
  và đổi mật khẩu mặc định (`123456`). Với agent-team chạy local thì cứ
  `127.0.0.1` là đủ.
- **Tuân thủ ToS**: định tuyến tài khoản subscription qua proxy bên thứ ba có thể
  vi phạm điều khoản của một số nhà cung cấp — cân nhắc trước khi dùng account
  trả phí cá nhân.

---

## 6. Lộ trình triển khai gợi ý

1. **PoC 1 dev**: cài `npm i -g 9router`, chạy, connect 1 provider free (Kiro /
   OpenCode). Sửa riêng `run_codex.sh` cho dev1 trỏ qua 9router. Chạy 1 task M.
2. **Đo**: so token/chi phí task đó có RTK vs không (dashboard 9router).
3. **Mở rộng**: thêm `USE_9ROUTER` vào `env.sh`, patch các wrapper còn lại, tạo
   combo theo bảng mục 3.3.
4. **Health-check**: thêm kiểm tra 9router vào `team-doctor.sh`.
5. **Đường lui**: tài liệu hóa cách tắt (`USE_9ROUTER=0`) khi proxy có sự cố.

---

*Tài liệu này chỉ là ý tưởng/kiến trúc đề xuất — chưa có code nào được thay đổi
trong repo. Bước tiếp theo nếu muốn: patch thật `.claude/bin/` theo mục 3.*
