# 04-agent-tools — GitCraque + surf-skill

Installs the two tools that sit on either side of an agent session: one to **read** the
history it produced, one to give it **research it can cite**.

Both are separate open-source projects by the same author, installed here from npm:

| Tool | npm | Repository |
|---|---|---|
| **GitCraque** | [`gitcraque`](https://www.npmjs.com/package/gitcraque) | <https://github.com/frederico-kluser/GitCraque> |
| **surf-skill** | [`surf-skill`](https://www.npmjs.com/package/surf-skill) | <https://github.com/frederico-kluser/surf-skill> |

## Install

| System | Command |
|---|---|
| Linux / macOS / Windows (Git Bash) | `./install.sh` |
| Windows (native PowerShell) | `powershell -ExecutionPolicy Bypass -File .\install.ps1` |

Run [`01-commands`](../01-commands/) first — it is what guarantees Node.js is present.

> The installer's own terminal output is in Portuguese.

### Two different Node floors, checked separately

| Tool | Requires | If your Node is older |
|---|---|---|
| `surf-skill` | Node ≥ 18 | the installer stops and tells you to run `01-commands` |
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

`surf-skill`'s own postinstall symlinks its three skills into the four skill directories it
knows about:

```
~/.agents/skills   ~/.claude/skills   ~/.codex/skills   ~/.pi/agent/skills
```

But `deepclaude` runs Claude Code with `CLAUDE_CONFIG_DIR=~/.claude-deepseek`, and personal
skills are read from `<CLAUDE_CONFIG_DIR>/skills`. **Without a bridge, the skills are
installed on disk and invisible in the agent you actually use.**

So this installer symlinks `surf-research-skill`, `surf-plan-skill` and `surf-free-skill`
into `~/.claude-deepseek/skills/` as well (a plain copy on Windows/MSYS, where symlinks need
a privilege you may not have). If a real directory already sits at one of those names, it is
left alone — your copy wins over ours.

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

## surf-skill — research that comes back with citations

Without it, an agent asked to "look this up" either guesses or burns your context window
orchestrating its own search loop. surf-skill moves that loop into a CLI: an LLM plans the
queries, they fan out concurrently across Tavily, Parallel AI and Brave with key rotation
and provider fallback, the LLM reads the harvest, searches again if something is still open,
and writes a cited answer.

The agent's job shrinks to writing a brief and picking a mode.

```bash
surf-search-normal  "<question>" --task … --goal … --insights …   # 1 round, fits the bash timeout
surf-search-unlimit "<question>" --max-rounds 6                    # as many rounds as it takes
```

| | `surf-search-normal` | `surf-search-unlimit` |
|---|---|---|
| Rounds | exactly 1 | until resolved (cap 6, `--max-rounds` up to 50) |
| Time | fitted inside the harness timeout | no self-imposed deadline |
| Typical | 45–110 s · ~$0.01–0.03 | 2–15 min · ~$0.03–0.15 |

**The brief is the whole job.** `--task` (what you are building) and `--goal` (the decision
this feeds) keep the planner on target; `--insights` (what you already believe) makes it
write queries that could *falsify* those beliefs; `--deliverable` shapes the output.

### Configuration

```bash
surf                            # wizard: Tavily / Parallel / Brave / OpenRouter keys,
                                # each validated live — an invalid key is NOT saved
surf-research-skill ai-setup    # just the OpenRouter key that powers the loop
                                # (validating it is free: key introspection, zero tokens)
surf-research-skill keys list   # what is stored, masked
surf doctor                     # is everything wired up?
```

Keys are only ever written to `~/.config/surf/keys.json` (chmod 600).

**Then, once per project** — this step is separate and easy to forget:

```bash
cd path/to/your-project
surf-research-skill project-config
```

It raises the harness's bash timeout so long research calls are not killed mid-flight. For
Claude Code it writes `.claude/settings.local.json` with `BASH_DEFAULT_TIMEOUT_MS=300000`
and `BASH_MAX_TIMEOUT_MS=600000` (up from a 120 s default). For GitHub Copilot CLI it writes
`.github/copilot-hooks.json` — and there it is effectively **required**, since that harness
defaults to a 30 s timeout.

### Nothing here is a hard blocker

| You have | What you get |
|---|---|
| search keys + OpenRouter key | the full loop: plan → fan out → analyze → synthesize |
| search keys only | real searches and a cited evidence brief, no synthesis — labelled `⚠ Degraded mode`, and that is **exit 0, a success**, not something to retry |
| OpenRouter key only | falls back to the keyless tier and still synthesizes |
| neither | `surf-free-skill "your query"` — Wikipedia + DuckDuckGo, zero setup |

That last row is why the installer lets you skip the key wizard: you can search on a fresh
machine with no account anywhere.

**One caution.** surf-ai feeds retrieved web pages to an LLM. Its prompts carry an explicit
rule that search results are untrusted data, but that is a mitigation, not a guarantee —
treat a synthesized answer like any web-sourced claim and never let an agent act on one
unreviewed. Your `--task`, `--goal` and `--insights` are sent to OpenRouter, so keep secrets
out of them.

---

## Verify the install

```bash
gitcraque --version
surf-free-skill "test query"          # works with no key at all
surf doctor
ls ~/.claude-deepseek/skills/         # the three surf-* skills must be here
```

That last line is the one worth checking: if those symlinks are missing, `deepclaude` cannot
see the skills.
