# 04-agent-tools — GitCraque + deep-orchestrator

Installs the two pieces that sit on either side of an agent session: one to **read** the
history it produced, one to **organize** the session itself.

Both are separate open-source projects by the same author — one installed from npm, one
cloned as a Claude Code skill:

| Tool | Installed as | Repository |
|---|---|---|
| **GitCraque** | npm package [`gitcraque`](https://www.npmjs.com/package/gitcraque) | <https://github.com/frederico-kluser/GitCraque> |
| **deep-orchestrator** | Claude Code skill, cloned and bridged | <https://github.com/frederico-kluser/deep-orchestrator> (v3.4.0, MIT) |

## Install

| System | Command |
|---|---|
| Linux / macOS / Windows (Git Bash) | `./install.sh` |
| Windows (native PowerShell) | `powershell -ExecutionPolicy Bypass -File .\install.ps1` |

Run [`01-commands`](../01-commands/) first if you want GitCraque — it is what guarantees
Node.js is present. **deep-orchestrator itself needs no Node at all.**

> The installer's own terminal output is in Portuguese.

### One Node floor, checked separately

| Tool | Requires | If your Node is older |
|---|---|---|
| `deep-orchestrator` | **none** | installs regardless — no Node, no problem |
| `gitcraque` | **Node ≥ 22.13** | GitCraque is **skipped with a warning**; everything else still installs |

GitCraque's floor is not arbitrary: it uses `node:sqlite`, which only drops the
`--experimental-sqlite` flag at 22.13. Raise Node (`nvm install 24`) and re-run the
installer — it is idempotent.

### It will not ask you for sudo

If the global npm prefix is not writable by your user, `npm i -g` would normally die with
`EACCES` and the usual advice is `sudo`, which installs for **root** and then vanishes from
your `PATH`. Instead the installer runs `npm config set prefix ~/.local`, so global binaries
land next to the ones the other installers publish — a directory already on your `PATH`.

### The part that is easy to get wrong

`deepclaude` runs Claude Code with `CLAUDE_CONFIG_DIR=~/.claude-deepseek`, and personal
skills are read from `<CLAUDE_CONFIG_DIR>/skills`. The main harness reads them from
`~/.claude/skills/`. **Without a bridge into both, the skill is installed on disk and
invisible in the agent you actually use.**

So this installer clones the skill into `~/.local/share/deep-orchestrator/` (set
`DEEP_ORCHESTRATOR_SRC` before running to point at a local path or another URL instead) and
bridges it — `SKILL.md` plus `scripts/`, `prompts/` and `templates/` — into
`~/.claude/skills/deep-orchestrator` **and** `~/.claude-deepseek/skills/deep-orchestrator`
(a junction on Windows — no admin needed — falling back to a plain copy when junctions are not available). If a real
directory already sits at one of those names, it is left alone — your copy wins over ours.

Set `DEEPCLAUDE_DIR` before running if your `deepclaude` config lives somewhere else; it is
the same variable the launcher reads.

---

## GitCraque — a desktop Git client with no Electron

A pure Node.js backend (`node:http`) drives the `git` binary through `child_process` and
serves a React SPA. The backend has **exactly one dependency**: `ws`.

```bash
cd ~/code/project && gitcraque    # opens your browser on the graph
gitcraque ~/code/project          # or point at a path, like `git -C`
gitcraque --repo ~ --port 5271
gitcraque --no-open               # don't open a browser
gitcraque --help                  # everything else
```

Default port is 5271; if it is taken GitCraque tries the next ten and tells you in the
banner which one it got, so several repositories can be open at once. Started outside a
repository, the screen is a picker — recents, a sweep of the usual folders, a folder
browser, and a `git init` — not an error.

**Why it belongs next to `qwe`.** Clicking a worktree label makes the *server* run
`process.chdir()` to that path and emit a WebSocket signal; the interface reloads from the
new directory. **No `git checkout` happens** — none of your working trees are touched. That
is exactly the shape of the worktrees `qwe` creates.

The rest of the tour: a history graph drawn as hand-written SVG from
`git log --all --topo-order` (no gitgraph library, window-virtualized so tens of thousands
of commits scroll smoothly); drag-and-drop with intent (a commit onto a branch proposes a
cherry-pick, a branch onto a branch offers merge or rebase, the raw command is shown first
and anything that rewrites history needs a press-and-hold); a graphical squash that
automates the interactive rebase by injecting `GIT_SEQUENCE_EDITOR` — no `vim` opens in your
face; and a push that never hangs, because `GIT_ASKPASS` points at a script fed over a unix
socket with a single-use nonce, so the token never touches the git process environment,
argv, or disk.

**Security.** It runs `git` on your machine. It listens on `127.0.0.1` only and refuses any
request whose `Host`/`Origin` comes from elsewhere. **Do not expose it to a network.**

> Installing with `npm i github:frederico-kluser/GitCraque` does **not** work: the published
> package ships the SPA pre-built and the build only runs on `npm pack`. From source, it is
> clone + `npm run build`.

---

## deep-orchestrator — the agent that organizes itself

A **Claude Code skill** (no binary, no npm package): an autonomous multi-agent orchestrator
that never writes code itself. It plans, splits the task into **waves** — unlimited, with
the plan recalculated after each wave by a PLAN REVISER sub-agent — creates a **named,
isolated git worktree per sub-agent**, delegates in parallel, applies **adversarial
review**, integrates each result via **squash-merge one at a time** (the gate — build +
tests + linter — runs on an integration snapshot in an ephemeral `int-ondaN-*` worktree),
removes worktree + branch + intermediate commits at the end of each wave, and commits
everything at the end **without asking the user anything**. Asynchronous **testing** and
**validation** subwaves (`test-ondaN-*`, `val-ondaN-*`) run after each wave. v3.4.0, MIT:
<https://github.com/frederico-kluser/deep-orchestrator>.

**Contained mode.** Invoked inside a git worktree — the kind [`qwe`](../01-commands/)
creates — the skill treats that worktree as its *root of the world*: it integrates into the
worktree's own branch, never `main`/`master`, and never writes to the main project. The
perfect pair with `qwe`: one creates the isolated room, the other works inside it and
cleans up after itself.

### Configure: the Brave key wizard (optional)

The installer offers a wizard at the end. Paste a **Brave Search API key**
(<https://api.search.brave.com/app/keys>); it validates the key **live**, stores it in
`~/.config/aula-dev/brave.key` (mode 600) and exports it from your rc (a marked
`BRAVE_API_KEY` block, added idempotently).

The orchestrator checks its search tiers before every wave and falls back through a
four-tier chain:

| Tier | Backend | Needs |
|---|---|---|
| 0 | the harness's own web search (in Claude Code: `WebSearch`/`WebFetch`) | nothing — no key, no script |
| 1 | the legacy AI-powered search skill — **no longer installed by this repo**; used only if the machine still has an old installation | nothing |
| 2 | Brave Search API | the wizard's key (optional) |
| 3 | DuckDuckGo keyless (Instant Answer, limited coverage) | nothing — always works |

**No key, no blocker.** Without a Brave key the search degrades to the harness's native
search (Tier 0) and/or the keyless tier (Tier 3) and stays operational —
`check-search-credits.sh` exits `1` in that state, which is expected and fine. Note that
Brave's model has been **metered since February 2026** — monthly credits, charged above the
quota — so the pre-wave credit check is also **financial** protection. Because installer 04
no longer ships the Tier-1 skill, a fresh machine searches through tiers 0/2/3: with the
Brave key (recommended, wizard) or keyless.

### Use it

```bash
/deep-orchestrator <task description>      # inside a project, or a `qwe` worktree
/deep-orchestrator max-parallel=N <task>   # optional: cap parallelism (default 20)
/deep-orchestrator plan=on <task>          # optional: force the plan-approval gate
/deep-orchestrator plan=off make a plan and run it   # force full autonomy
```

Trigger phrases: *"orquestre isso"*, *"resolva do início ao fim"*, *"não me pergunte nada"*,
*"toca o barco"* — plus, for the plan-approval gate, *"faça um plano"*, *"planeje"*,
*"quero aprovar antes"*. The class example — *add rate limiting to an Express API* — becomes
an orchestration of two or more waves with named worktrees, ending as squash commits on your
branch plus a final commit. Not for trivial one-line tasks.

### The plan-approval gate (Plannotator)

When the invocation **asks for a plan**, the orchestrator stops at **Phase 2.5** and sends
the plan to the [Plannotator](https://github.com/backnotprop/plannotator) in your browser.
You **approve or annotate** it there; every annotation **regenerates the plan and opens a
brand-new Plannotator** (new process, new server, new tab — never a patch on the previous
session) until approval or the revision budget (default 5) runs out. **No worktree, branch
or commit exists before the plan is approved** — that is why the gate lives here: rejecting
the plan costs no rollback.

- **How it turns on** — by precedence: the `plan=on`/`plan=off` prefix > the
  `DO_PLAN_APPROVAL` environment variable > negative triggers (*"não me pergunte nada"*,
  *"autônomo"*, *"toca o barco"*) > positive triggers (*"faça um plano"*, *"planeje"*,
  *"quero aprovar antes"*, *"revisar o plano"*) > **default off**. No prefix, no trigger —
  no browser ever opens, and autonomy is exactly as it always was.
- **Self-installing** — `check-plannotator.sh --install` resolves the executable (explicit
  `$DO_PLANNOTATOR_BIN` → `PATH` → `~/.local/bin`), checks the version (minimum **0.19.1**)
  and installs it if missing: **only the binary**, without touching `~/.claude`, `~/.codex`,
  `~/.gemini` or `~/.config/opencode`, never `sudo`, never `npm -g`. An existing install is
  never overwritten.
- **Verdict by exit code, never by text** — `plan-approval.sh round` returns 0 approved ·
  10 annotated · 11 closed · 12 timeout · **13 tool failure** · 14 budget exhausted (default cap: 5 revisions);
  each round leaves an immutable snapshot (`rev-NNN.md`), its feedback file and a
  `trail.tsv` line.
- **Hard rules** — the plan title is immutable between revisions (a changed title is
  refused, the same rule Plannotator itself enforces); the approved plan becomes a
  constraint the PLAN REVISER enforces, and out-of-scope proposals reopen the gate once
  from the same budget.
- **Network locks, both on by default** — `PLANNOTATOR_SHARE=disabled` blocks uploading the
  plan text to the paste service, and `PLANNOTATOR_REMOTE=0` keeps the server on
  `127.0.0.1`. Reviewing over SSH therefore requires a tunnel:
  `ssh -L 19432:127.0.0.1:19432 <host>`.

### Security

The orchestrator's sub-agents run commands on your machine, each inside its own disposable
worktree, and web search feeds page content to them — search results are untrusted data,
and the prompts say so. Without a Brave key the search degrades to the harness's native
search and the keyless tier — degraded, but never a hard blocker; the only hard stop is
when **no** search tier is available at all while the task needs research.

---

## Verify the install

```bash
gitcraque --version
ls -l ~/.claude-deepseek/skills/deep-orchestrator   # deepclaude's view — the one to check
ls -l ~/.claude/skills/deep-orchestrator            # the main harness's view
~/.local/share/deep-orchestrator/scripts/check-search-credits.sh   # 0 = full search, 1 = keyless
ls -l ~/.local/share/deep-orchestrator/scripts/check-plannotator.sh   # the plan gate's installer
```

That middle pair is the one worth checking: if those directories are missing, `deepclaude`
cannot see the skill.

