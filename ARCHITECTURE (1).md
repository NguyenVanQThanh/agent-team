# ARCHITECTURE — Multi-Agent Dev Team

> Tài liệu thiết kế kiến trúc cho hệ thống multi-agent development kết hợp 4 thành phần chính:
> **command-output compression (RTK)** + **payload compression & memory (Headroom)**
> + **orchestration (agent-team)** + **thinking (Superpowers)** (+ tùy chọn Serena / Unsloth).
> Mục tiêu: một leader điều phối nhiều dev CLI (Claude / Codex / DeepSeek / Gemini) chạy song song,
> có tư duy quy trình chuẩn, nhớ xuyên session, và tiết kiệm token ở cả 2 tầng.

---

## ⚑ Trạng thái triển khai — cập nhật 2026-07-09

> Cập nhật sau khi verify thực tế trên môi trường Windows của dự án. Bản thiết kế
> gốc (các mục bên dưới) giữ lại làm hồ sơ; bảng này là **quyết định cuối**.

| Tầng | Thành phần | Quyết định | Lý do (đã verify) |
|---|---|---|---|
| 0 | **RTK** | ✅ **ADOPTED** | Nén ~32% mẫu kênh lệnh shell. Hook đã cài: Claude Code (global), Codex (AGENTS.md/RTK.md — instruction), Gemini (global). Rủi ro thấp. |
| 1 | **Headroom** | ❌ **REJECTED — đã gỡ** | `learn` chết trên Windows (npm shim + litellm parse). `proxy` chạy được với subscription **nhưng nén 0%** vì Claude Code prompt-cache đóng băng prefix (`prefix_frozen`) — Headroom cố ý không đụng cache. Giá trị ~0 + rủi ro proxy-in-path (cùng loại 9router đã revert). |
| 2 | **agent-team** | ✅ giữ nguyên | Tầng điều phối chính, không đổi. |
| 3 | **Superpowers** | 🚧 **IN PROGRESS** | Cài qua `/plugin install`. **Phải tắt** `subagent-driven-development` + `dispatching-parallel-agents` (đá nhau với leader) — cơ chế disable đang xác minh. |

**Bài học then chốt (để người sau khỏi thử lại):**
- Headroom `proxy` **không** nén được kênh Read của Claude Code: prompt caching của Claude đã ăn phần lợi đó; con số "opportunity" từ `audit-reads` là byte thô, không hiện thực hóa qua proxy.
- Headroom `learn` cần LLM backend; trên Windows binary `claude` là npm shim → subprocess không chạy được, và litelln/deepseek trả JSON lỗi.
- ⇒ RTK (kênh Bash) là thắng lợi thật duy nhất ở 2 tầng nén. Headroom đã gỡ khỏi `env.sh`, `team-doctor.sh`, `README.md`.

---

## 0. Repo tham chiếu

| Thành phần | Repo / Link | Vai trò | Tầng |
|---|---|---|---|
| Command-output compression | https://github.com/rtk-ai/rtk | Rust binary nén output lệnh shell (git/test/lint/docker...) | 0 |
| Payload compression + Memory | https://github.com/headroomlabs-ai/headroom | Proxy nén payload API + Persistent Memory + SharedContext + Failure Learning | 1 |
| Headroom Docs | https://headroom-docs.vercel.app | Tài liệu chính thức (proxy, memory, configuration) | — |
| Orchestration | https://github.com/NguyenVanQThanh/agent-team | Leader + 14 dev song song, spawn-team, 3-phase | 2 |
| Methodology | https://github.com/obra/superpowers | Skill + hook: brainstorm → plan → TDD → review | 3 |
| Code memory (optional) | https://github.com/oraios/serena | Symbol-level code memory qua MCP | opt |
| Local model serving (optional) | https://github.com/unslothai/unsloth | Chạy model fine-tune local qua endpoint OpenAI-compatible | opt |

---

## 1. Tổng quan các tầng

Hệ thống chia thành 4 tầng độc lập, **mỗi tầng làm đúng một việc, không đá nhau**.

```
┌───────────────────────────────────────────────────────────────┐
│  TẦNG 3 — THINKING / METHODOLOGY   ·  Superpowers              │
│  brainstorm → writing-plans → TDD → code-review → verify        │
│  (cài cho leader + dev Claude/Codex; TẮT subagent-driven-dev)   │
└───────────────────────────────────────────────────────────────┘
                          ▲ định hình cách agent suy nghĩ
                          ▼
┌───────────────────────────────────────────────────────────────┐
│  TẦNG 2 — ORCHESTRATION            ·  agent-team               │
│  leader (Claude Opus) ── spawn-team.sh ──> 14 dev process       │
│  Phase 1 (pre) → Phase 2 (impl) → Phase 3 (post)                │
│  (giữ nguyên logic gốc; đây là tầng điều phối DUY NHẤT)         │
└───────────────────────────────────────────────────────────────┘
                          ▲ mọi request đi xuyên xuống dưới
                          ▼
┌───────────────────────────────────────────────────────────────┐
│  TẦNG 1 — PAYLOAD COMPRESSION + MEMORY  ·  Headroom            │
│  ├─ proxy            : nén payload API (history/RAG/file)       │
│  ├─ SharedContext    : nén context khi leader ⇄ dev handoff     │
│  ├─ Persistent Memory: mỗi dev nhớ theo project                 │
│  └─ Failure Learning : ghi bài học vào CLAUDE/AGENTS/GEMINI.md   │
└───────────────────────────────────────────────────────────────┘
                          ▲ nén ở tầng đường truyền API
                          ▼
┌───────────────────────────────────────────────────────────────┐
│  TẦNG 0 — COMMAND-OUTPUT COMPRESSION  ·  RTK                   │
│  hook rewrite: `git status` → `rtk git status` ... (~100 lệnh)  │
│  nén output NGAY TẠI NGUỒN, trước khi vào context               │
│  phủ được cả dev Gemini/DeepSeek (có hook riêng)                │
└───────────────────────────────────────────────────────────────┘
```

**Hai tầng nén ở hai chỗ khác nhau:** RTK cắt output lệnh *tại nguồn* (trước khi vào context);
Headroom nén *toàn bộ payload* đã lắp ráp (history, RAG, file) trước khi bay lên API. Không trùng.

---

## 2. Vai trò chi tiết từng tầng

### 2.0. Tầng 0 — RTK (nén output lệnh)

- Rust binary, zero-dependency, overhead <10ms. Cài: `brew install rtk` hoặc `cargo install --git ...`.
- Hook rewrite Bash command → phiên bản `rtk` trước khi chạy: `git push` (200 token) → `ok main` (10 token); `cargo test` (200+ dòng) → ~20 dòng chỉ failure.
- Hỗ trợ hook riêng cho **Claude Code, Codex, Gemini CLI** (`rtk init -g --gemini` / `--codex`) → phủ được các dev mà Headroom proxy còn bỏ ngỏ.
- **Giới hạn:** hook chỉ bắt Bash tool call. Built-in `Read`/`Grep`/`Glob` của Claude Code KHÔNG qua hook → dùng shell command hoặc gọi `rtk read`/`rtk grep` trực tiếp.

### 2.1. Tầng 1 — Headroom (nén payload + memory)

| Tính năng | Mô tả | Chế độ chạy |
|---|---|---|
| **proxy compression** | Nén payload API (history, RAG, file lớn) trước khi tới LLM | `headroom proxy` — dùng chung cả team |
| **SharedContext** | Nén ~80% khi agent bàn giao context cho nhau | ⚠️ cần verify ở proxy mode (§5) |
| **Persistent Memory** | SQLite + HNSW vector store, per-project, không lẫn cross-project | ⚠️ docs minh họa qua SDK — cần verify proxy mode (§5) |
| **Failure Learning** | `headroom learn` quét log, tìm lỗi & cách sửa, ghi vào file context | ✅ chạy độc lập qua CLI — chắc chắn dùng được |

### 2.2. Tầng 2 — agent-team (xương sống điều phối)

- Leader nhận yêu cầu, chia task, spawn dev qua `spawn-team.sh`. Cấu hình CLI tập trung tại `.claude/bin/env.sh`.
- Mỗi dev là 1 tiến trình CLI riêng (`codex`, `deepseek`, `claude`, `gemini`).
- Workflow 3 phase: pre → impl (song song) → post (tổng hợp, memory, review).
- **Đây là tầng điều phối DUY NHẤT.** Không chồng cơ chế orchestrator nào khác lên nó.

### 2.3. Tầng 3 — Superpowers (tư duy)

- Cài như plugin ở tầng harness của từng CLI được hỗ trợ.
- Trong dàn 14 dev: **chỉ Claude và Codex** có Superpowers. DeepSeek/Gemini không có plugin.
- Skill áp dụng: `brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`, `requesting-code-review`, `verification-before-completion`.

---

## 3. Cách các tầng cắm vào nhau (data flow)

```
  RTK cắt output lệnh ─→ Headroom nén phần payload còn lại ─→ LLM
  leader ──SharedContext (nén handoff)──> dev
  dev ──Persistent Memory (per-project)──> nhớ xuyên session
  sau mỗi batch: headroom learn --apply → CLAUDE/AGENTS/GEMINI.md
                 dev10 → .claude/memory/ (vault chi tiết)
  RTK gain --format json → số liệu token tiết kiệm theo ngày
```

**Điểm khớp đẹp nhất — Failure Learning ↔ dev10:** agent-team đã có sẵn `CLAUDE.md`,
`AGENTS.md`, `GEMINI.md` ở root — đúng 3 file `headroom learn` ghi vào (trong section
đánh dấu `<!-- headroom:learn:start/end -->`, không đụng phần còn lại). Phân vai: dev10
viết memory chi tiết vào `.claude/memory/`; `headroom learn` lo phần "lỗi lặp lại → nhắc
agent" ở tầng prompt injection.

---

## 4. Các điểm chồng lấn CẦN NÉ

| Xung đột tiềm tàng | Vì sao | Giải pháp |
|---|---|---|
| Superpowers `subagent-driven-development` vs agent-team leader | Cả hai đều "chia task → spawn subagent → review 2 giai đoạn" | **TẮT** skill `subagent-driven-development` + `dispatching-parallel-agents` ở leader. Điều phối chỉ do agent-team lo. |
| RTK vs Headroom (cùng nén output lệnh) | Cả hai đều có thể nén output `cargo test`, `git`... → nén 2 lần, thừa | Khoanh vai: **RTK** lo output lệnh; **Headroom** lo payload còn lại (history, RAG, file qua built-in Read). |
| Serena memory vs Headroom Persistent Memory | Cả hai đều là "memory" | Chọn một. Symbol-level code → Serena. Fact/lịch sử → Headroom. Xem §6. |
| Headroom compression cho model local (Unsloth) | Model local free → chỉ số "$ saved" vô nghĩa | Lợi ích thật là tiết kiệm context window. Tắt LLMLingua nếu VRAM hạn chế (đụng GPU với model). |

---

## 5. Điểm CẦN TỰ KIỂM CHỨNG (chưa xác nhận 100%)

1. **SharedContext & Persistent Memory ở chế độ proxy/wrap:** docs Headroom minh họa qua SDK
   wrapper (`with_memory(OpenAI())`), chưa rõ có tự bật khi chạy `headroom proxy`/`wrap`.
   Vì agent-team gọi CLI trực tiếp (không qua code SDK), cần test. Nếu chỉ có ở SDK → chỉ
   dùng được **Failure Learning** qua CLI (vẫn là phần khớp nhất).

2. **DeepSeek / Gemini CLI đọc `OPENAI_BASE_URL`-style override không?** Claude + Codex chắc
   chắn support (trong compatibility matrix Headroom). DeepSeek/Gemini cần test trỏ base_url về
   proxy. Nếu không → 2 dev đó không qua Headroom, NHƯNG vẫn được **RTK** nén output lệnh.

---

## 6. Tùy chọn mở rộng

### 6.1. Serena (code memory) — nếu cần hiểu symbol-level
```bash
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena \
  serena start-mcp-server --context ide-assistant --project "$(pwd)"
```
Serena chạy như MCP subprocess của từng CLI (stdio) → Headroom vẫn nén dòng ra/vào LLM bình thường.
Không cài Serena chỉ để dùng Headroom — hai cái độc lập.

### 6.2. Unsloth (local fine-tuned model) — nếu route model local qua proxy
```bash
# 1. chạy Unsloth serve (OpenAI-compatible), vd port 8001
# 2. Headroom proxy trỏ upstream về Unsloth
headroom proxy --port 8787 --openai-api-url http://127.0.0.1:8001
#    hoặc: export OPENAI_TARGET_API_URL=http://127.0.0.1:8001
# 3. CLI trỏ vào Headroom
OPENAI_BASE_URL=http://localhost:8787/v1 codex
```
Luồng: `CLI → RTK (nén output) → Headroom (nén payload) → Unsloth (model local) → response`.

---

## 7. Thứ tự khởi động (bootstrap order)

```
1. (optional) Unsloth serve         → nếu dùng model local
2. RTK: rtk init -g (+ --gemini/--codex)  → cài hook cho từng CLI
3. headroom proxy --port 8787       → BẬT TRƯỚC mọi request API
4. cấu hình .claude/bin/env.sh      → trỏ ANTHROPIC/OPENAI_BASE_URL về proxy
5. cài Superpowers                  → cho leader + dev Claude/Codex
6. (optional) claude mcp add serena
7. leader khởi động agent-team      → spawn-team.sh
8. sau mỗi batch: headroom learn --project . --apply
```

Kiểm tra:
```bash
rtk gain              # token tiết kiệm ở tầng output lệnh
headroom doctor       # verify proxy + config
headroom dashboard    # token tiết kiệm ở tầng payload (thấy traffic mỗi dev)
```

---

## 8. Checklist trước khi chạy production

- [ ] RTK cài xong, `rtk gain` thấy số liệu; đã init hook cho Gemini + Codex
- [ ] `headroom proxy` chạy, `headroom dashboard` thấy traffic dev Claude + Codex
- [ ] `env.sh` set base URL Claude + Codex về proxy
- [ ] Test: DeepSeek / Gemini CLI có qua proxy không? (nếu không → dựa vào RTK)
- [ ] Superpowers đã TẮT `subagent-driven-development` + `dispatching-parallel-agents` ở leader
- [ ] `headroom learn --apply` ghi đúng section marker, không phá nội dung cũ CLAUDE/AGENTS/GEMINI.md
- [ ] dev10 vẫn ghi `.claude/memory/` — không trùng Failure Learning
- [ ] Xác nhận SharedContext / Persistent Memory hoạt động ở proxy mode (§5.1)
- [ ] Nếu dùng Unsloth: tắt LLMLingua tránh tranh GPU với model local
- [ ] RTK ↔ Headroom đã khoanh vai rõ (không nén 2 lần cùng output lệnh)

---

*Tài liệu này là bản thiết kế (design doc), không phải hướng dẫn cài đặt cuối cùng.
Các mục ⚠️ trong §5 cần kiểm chứng thực tế trước khi chốt kiến trúc.*
