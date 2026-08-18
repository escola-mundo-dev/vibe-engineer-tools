# 03-deepclaude — Claude Code on a DeepSeek brain

Installs **`deepclaude`**: the official Claude Code CLI — the whole harness, with its
tools, subagents, skills and slash commands — pointed at DeepSeek's own
Anthropic-compatible endpoint (`https://api.deepseek.com/anthropic`), at DeepSeek prices.
Plus **`deepeco`**, which tells you whether the cheap pricing window is open right now.

## Install

| System | Command |
|---|---|
| Linux / macOS / Windows (Git Bash) | `./install.sh` |
| Windows (native PowerShell) | `powershell -ExecutionPolicy Bypass -File .\install.ps1` |

The installer asks for your **DeepSeek API key** (create one at
<https://platform.deepseek.com/api_keys>), **validates it against the live API** before
writing it anywhere — `GET /user/balance`, which costs no tokens and prints your balance;
a 401 makes it ask again — and stores it at `~/.claude-deepseek/deepseek.key` with mode
`600`. To replace it later: `deepclaude --setup-key`.

It also installs Claude Code itself if you don't have it (official native installer, npm
fallback).

> The installer's own terminal output is in Portuguese.

## What you end up with

| Command | What it does |
|---|---|
| `deepclaude` | Claude Code with the six DeepSeek model pins. Default: **V4 Flash `[1m]`** (build 0731). Prints the `deepeco` status banner on launch. |
| `deepclaude --pro` | the whole session on V4 Pro — heavy codegen and refactors |
| `deepclaude --setup-key` | ask for, validate, and store the key (globally) |
| `deepeco` | banner + status + a table of windows and prices in **your** timezone |
| `/eco` | the same, from inside a `deepclaude` session |
| `/model fable` ⇄ `/model sonnet` | V4 Pro ⇄ V4 Flash without restarting |

## Why the six model pins are not optional

DeepSeek's endpoint maps model names **by prefix**:

```
claude-opus-*    →  deepseek-v4-pro
claude-sonnet-*  →  deepseek-v4-flash     ← this is why the sonnet pin matters
claude-haiku-*   →  deepseek-v4-flash
```

The CLI calls its main agent "sonnet" on several routes. So **a missing pin does not raise
an error — it silently swaps your model.**

The same trap applies to a typo. The official docs are explicit that the `/anthropic` route
does not reject an unknown model, it *remaps* it: "the API backend will automatically map it
to the `deepseek-v4-flash` model". A typo in the Pro pin quietly demotes the session to
Flash, with HTTP 200 all the way. The only valid ids here are `deepseek-v4-flash` and
`deepseek-v4-pro`, with an optional `[1m]` suffix. Dated ids (`deepseek-v4-pro-0813`) and
gateway-prefixed ids (`deepseek/...`) **do not exist on this API** — those are OpenRouter
strings.

The launcher is the **single source of truth** for this environment. Don't re-declare the
pins in your shell profile; a second copy is a chance for silent drift.

Beyond the pins it sets `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576` and
`CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432` (75% of 1M), both prescribed by DeepSeek's own
Claude Code guide. Declaring only the window is not enough: output can reach 384K tokens
and has to fit in whatever is left.

## What you give up versus native Claude

This is a real trade, not a free lunch. Going through the compatibility layer costs you:

- **Vision and multimodal.** The layer rejects `type = "image"` and `type = "document"`
  content blocks. Front-end work from a screenshot needs the real Anthropic backend.
- **MCP.** `mcp_servers`, `mcp_tool_use` and `mcp_tool_result` are ignored or refused —
  every MCP connector you rely on goes dark.
- **`cache_control`.** Ignored, so you cannot place manual prompt-cache breakpoints.
- **`thinking.budget_tokens`.** Accepted but not honored — DeepSeek uses a qualitative
  `reasoning_effort` instead. The mismatch is what produces
  `API Error: 400 thinking options type cannot be disabled when reasoning_effort is set`.
- **Parallel tool calls** frequently serialize in practice: cheaper, but slower in
  wall-clock on wide refactors.
- **Sandboxed execution** (`code_execution_tool_result`, `container`, `container_upload`)
  is unsupported. Native web search **is** still supported, routed to DeepSeek's own engine.
- **Hallucination profile.** V4 Pro scored a 94% hallucination propensity on
  AA-Omniscience — inside an agent loop, an invented package name can turn into a real
  install attempt and a real rabbit hole.
- **Data retention.** Sending proprietary code to public DeepSeek infrastructure gives up
  the zero-data-retention guarantees of Anthropic's paid tiers.

If an agent reports edits it never made — the "tool call black hole" — the fix is:

```bash
export CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING=0
```

## The pricing window (`deepeco`)

The old off-peak discount (16:30–00:30 UTC, 50% chat / 75% reasoner) **ended on
2025-09-05**. Since **2026-08-16 16:00 UTC** a peak/off-peak regime applies, defined in UTC
by the **API server's** clock. `deepeco` converts it to your local timezone automatically.

| Band | UTC | Brazil (UTC−3) | Price |
|---|---|---|---|
| **Peak** | 01:00–04:00 and 06:00–10:00 | 22:00–01:00 and 03:00–07:00 | 2× |
| **Off-peak** | the other 17 hours | 01:00–03:00 and 07:00–22:00 | half of peak, all models |

Per 1M tokens (cache hit / cache miss / output):

| Model | Off-peak | Peak |
|---|---|---|
| `deepseek-v4-flash` | `$0.007 / $0.22 / $0.66` | `$0.014 / $0.44 / $1.32` |
| `deepseek-v4-pro` | `$0.022 / $0.66 / $1.98` | `$0.044 / $1.32 / $3.96` |

Source: [official DeepSeek pricing](https://api-docs.deepseek.com/quick_start/pricing/).

**Read this honestly: structurally it was a price increase.** Peak is roughly 4× the flat
rate that applied until 2026-08-15, and even the new off-peak tariff is above that old flat
rate. What is genuinely good news is the *shape*: Brazilian business hours (07:00–22:00)
fall entirely inside off-peak, and the peaks land overnight.

One caveat the documentation does not settle: whether the **start** or the **completion**
time of a request is what counts. In the 2025 policy it was completion. Near a boundary,
leave margin on long tasks.

The window, the tariffs and the effective date live in `~/.config/aula-dev/deepeco.conf` —
when DeepSeek changes the policy you edit that file, not the scripts.

## What it puts on your machine

- `~/.local/bin/deepclaude`, `~/.local/bin/deepeco` (on Windows: `.ps1` files plus `.cmd`
  shims and bash wrappers, so `/eco` works from Git Bash too)
- `~/.claude-deepseek/` — this account's isolated Claude Code config, plus
  `commands/eco.md` and `deepseek.key`
- `~/.config/aula-dev/deepeco.conf`

Because this account uses its own `CLAUDE_CONFIG_DIR`, its personal skills live in
`~/.claude-deepseek/skills/` — which is why [`04-agent-tools`](../04-agent-tools/) has to
bridge the `surf-*` skills into it explicitly.
