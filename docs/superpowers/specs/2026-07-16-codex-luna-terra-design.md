# Codex Luna/Terra Team Design

**Goal:** Expand the Codex pool from four to six teammates with an even split between `gpt-5.6-luna` and `gpt-5.6-terra`, using medium reasoning only.

**Routing:** Luna handles S/M work where low latency is preferred. Terra handles M/L work, including larger or cross-module tasks. M is the overlap: simple, local M tasks go to Luna; multi-file or architectural M tasks go to Terra.

**Roster:** `dev1`, `dev12`, and new `dev15` use Luna; `dev2`, `dev13`, and new `dev16` use Terra. Existing DeepSeek, Claude, and Gemini roles remain unchanged for provider diversity and specialist duties.

**Constraints:** No Codex dev uses low, high, or xhigh reasoning. XL remains an escalation/tournament concern and is not widened by this change.

**Verification:** Validate every Codex persona has the intended model/size bracket, every per-dev flag is exported and selected by `_runner.sh`, and repository routing documentation reports six Codex devs.
