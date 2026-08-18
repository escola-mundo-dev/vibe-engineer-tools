# vibe-engineer-tools

The terminal setup used in the **Mundo Dev** class on AI-assisted development: four
idempotent installers that give you a project picker, disposable git worktrees, a terminal
tuned for agent output, Claude Code running on a DeepSeek brain, and two companion projects
— **GitCraque** (a desktop Git client with no Electron) and **surf-skill** (autonomous web
research for coding agents).

This README is in English. **The installers themselves speak Portuguese** — every prompt,
warning and success line you see in the terminal is pt-BR, by design: they were written for
a Brazilian classroom. Their behaviour is documented here in full, so you never have to
guess what a message means.

## The problem this solves

An agent that can edit your repo is fast. It is also, out of the box, **messy** (it works on
your checked-out branch, so a half-finished experiment and your real work share one working
tree — parallel tasks are not an option), **blind** (it answers from training data,
confidently writing the call signature that changed four months ago), **expensive** (most of
the spend is re-sending context the provider already saw), **unreadable** (after twenty
minutes of streaming, "what did it actually commit?" is a question `git log --oneline`
answers badly and a graph answers instantly), and **noisy** (default scrollback truncates a
long session, so the error you want scrolled off an hour ago).

None of those are model problems. They are *harness* problems, and each has a concrete fix
that fits in a shell function, a config file, or a small local tool.

## The loop

```
projects                              land in the right repo, two keystrokes
  └─ qwe add-rate-limit -a deepclaude  isolated worktree + agent inside it
       └─ "research X first"            surf-* skills: cited answers, not guesses
            └─ gitcraque                read the resulting history as a graph
                 └─ up                  back to the main repo, merge consciously
                      └─ deepeco        schedule the heavy runs for the cheap window
```

This is one workflow, not four unrelated scripts. The pairing that is easiest to miss:
**`qwe` creates worktrees and GitCraque switches between them with `process.chdir()` instead
of `git checkout`** — nobody's working tree is touched while you read another task's branch.
Everything above streams through **Ghostty**, configured with a 100 MB scrollback precisely
because agent sessions print a lot.

## What is in the box

| Installer | Installs | Gives you |
|---|---|---|
| [`01-commands`](01-commands/) | Node.js (if missing), `projects-picker` | `projects`, `qwe`, `up` |
| [`02-ghostty`](02-ghostty/) | Ghostty + JetBrainsMono Nerd Font | a terminal that survives an agent |
| [`03-deepclaude`](03-deepclaude/) | Claude Code (if missing), 2 launchers | `deepclaude`, `deepeco`, `/eco` |
| [`04-agent-tools`](04-agent-tools/) | `gitcraque`, `surf-skill` from npm | `gitcraque`, `surf-*`, agent skills |

Each folder has its own README with the same material at reference depth. Two of the tools
are **separate open-source projects by the same author**, installed from npm rather than
vendored here — file issues and stars upstream:

| Project | Repo | npm | License |
|---|---|---|---|
| **GitCraque** | [frederico-kluser/GitCraque](https://github.com/frederico-kluser/GitCraque) | `gitcraque` | MIT |
| **surf-skill** | [frederico-kluser/surf-skill](https://github.com/frederico-kluser/surf-skill) | `surf-skill` | MIT |

## Contents

- [Before you install](#before-you-install)
- [Install](#install)
- **The journey** — one task, end to end
  - [Stop 0 — the surface you watch it on (Ghostty)](#stop-0--the-surface-you-watch-it-on-ghostty)
  - [Stop 1 — land in the repo (projects)](#stop-1--land-in-the-repo-projects)
  - [Stop 2 — an isolated place to work (qwe)](#stop-2--an-isolated-place-to-work-qwe)
  - [Stop 3 — the agent (deepclaude)](#stop-3--the-agent-deepclaude)
  - [Stop 4 — the agent stops guessing (surf-skill)](#stop-4--the-agent-stops-guessing-surf-skill)
  - [Stop 5 — read the history (GitCraque)](#stop-5--read-the-history-gitcraque)
  - [Stop 6 — come back and merge (up)](#stop-6--come-back-and-merge-up)
  - [Stop 7 — the cheap window (deepeco)](#stop-7--the-cheap-window-deepeco)
- **Reference**
  - [Where everything lands](#where-everything-lands)
  - [Commands](#commands)
  - [deepclaude environment overrides](#deepclaude-environment-overrides)
  - [Why the workflow is shaped like this: prompt caching](#why-the-workflow-is-shaped-like-this-prompt-caching)
  - [Troubleshooting](#troubleshooting)
  - [Uninstall](#uninstall)
  - [Repository layout](#repository-layout)
  - [Credits](#credits)

---

## Before you install

| You need | For | If it is missing |
|---|---|---|
| `git` | everything | `01-commands` stops with per-OS instructions: `sudo apt install git` (Linux), `xcode-select --install` (macOS), `winget install --id Git.Git -e` (Windows) |
| `curl` | 01 · 02 · 03 | used for `nvm`, the Nerd Font archive, the Claude Code installer and the API key check |
| **Node.js ≥ 18** | 01 · 04 | `01-commands` installs it: Homebrew on macOS (**and fails if Homebrew is absent** — <https://brew.sh>), `nvm` v0.40.6 + `nvm install 24` on Linux, `winget OpenJS.NodeJS.LTS` on Git Bash |
| **Node.js ≥ 22.13** | GitCraque only | `04-agent-tools` **skips GitCraque with a warning** and installs everything else. `nvm install 24`, then re-run `./install.sh 04` |
| `sudo` + a supported package manager | 02 on Linux | `apt` (with the `mkasberg/ghostty-ubuntu` PPA), `pacman`, `dnf copr`, `zypper`, or `snap`. On an unrecognized distro with no snap, the script stops and points at <https://ghostty.org/docs/install/binary> |
| `unzip` or `tar`, plus fontconfig | 02 on Linux | to unpack and register JetBrainsMono Nerd Font (`fc-cache`, `fc-list`) |
| A funded **DeepSeek** account | 03 | create a key at <https://platform.deepseek.com/api_keys> — the installer validates it before storing it |

**On a machine with no Node at all, the full run legitimately takes two passes.** This is
not a bug and the scripts say so, in Portuguese:

- **Git Bash:** `01-commands` installs Node through `winget`, prints *"FECHE e REABRA o Git
  Bash"* and exits 0. Close the window, open a new one, run `./install.sh` again.
- **Linux:** `01-commands` installs Node through `nvm` **inside its own subshell**, so the
  parent run's `PATH` never sees it and `04-agent-tools` stops with *"Node.js não
  encontrado"* right after `01` succeeded. Open a new terminal and run `./install.sh 04`.

## Install

```bash
git clone https://github.com/escola-mundo-dev/vibe-engineer-tools.git
cd vibe-engineer-tools
./install.sh
```

That runs `01 → 02 → 03 → 04` in order. **The order matters**: `01-commands` is what
installs Node.js, and `04-agent-tools` needs it.

```bash
./install.sh --list           # show the installers that exist, then exit
./install.sh 01 03            # run only these, in the order you listed them
./install.sh 04-agent-tools   # full folder name works too
```

Every folder's `install.sh` also runs standalone (`cd 01-commands && ./install.sh`). If you
already ran `./install.sh`, you have all four — the `./install.sh NN` lines in the journey
below are there so you can install a single piece, or re-run one after fixing something.

Ground rules that hold for every installer here:

| Rule | Why |
|---|---|
| **Idempotent** — safe to re-run | You will re-run them. A failed step should not require a clean machine. |
| **Per-user, never as root** | The scripts refuse to start as root: `sudo ./install.sh` would install into `/root` and silently vanish from your `PATH`. Genuinely root (container, WSL)? `AULA_PERMITIR_ROOT=1 ./install.sh`. |
| **`sudo` only where a package manager needs it** | `02-ghostty` is the one that calls `sudo` itself, for `apt`/`pacman`/`dnf`/`zypper`/`snap`. Expect a password prompt there and nowhere else. |
| **Backs up the things you edit** | `02-ghostty` copies an existing `config.ghostty` to `.bak-<timestamp>` and moves a legacy `config` aside; `03-deepclaude` backs up a `deepeco.conf` that differs. The installers' own payload files (`comandos.sh`, the picker bundle, `themes/dracula`, the launchers, `eco.md`) are overwritten in place — keep local edits elsewhere. |
| **Fails loudly, stops there** | If `03` fails, `01` and `02` still hold; nothing is rolled back. Fix and re-run just that one. |
| **`bash "$script"`, not `./script`** | A clone that lost the execute bit (zip download, Windows, `core.fileMode false`) still installs. |

The ASCII banner is cosmetic — `MUNDO_DEV_BANNER=0` turns it off everywhere. Where it
matters it goes to stderr: the `comandos.sh` functions and the `deepclaude` launcher redirect
it, so a `projects` command substitution can never receive the banner instead of a path. The
installers themselves print theirs on stdout, which is harmless — you run those by hand.

### Platforms

| | Linux | macOS | Windows |
|---|---|---|---|
| `01-commands` | yes | yes | Git Bash |
| `02-ghostty` | yes (`sudo` for the package manager) | yes (Homebrew) | **no official build (Aug 2026)** — prints the WSL2 / [winghostty](https://winghostty.com/) routes and exits `0` |
| `03-deepclaude` | yes | yes | Git Bash, or native PowerShell |
| `04-agent-tools` | yes | yes | Git Bash, or native PowerShell |

On Windows, run `./install.sh` inside **Git Bash**. There is no root `install.ps1`: for
native PowerShell you call the two that exist directly, and because PowerShell blocks
unsigned scripts by default the invocation needs the flag:

```powershell
powershell -ExecutionPolicy Bypass -File .\03-deepclaude\install.ps1
powershell -ExecutionPolicy Bypass -File .\04-agent-tools\install.ps1
```

GitCraque publishes a **Linux and macOS** platform badge; `04-agent-tools` will still install
the npm package on Windows, and its only stated requirements are Node >= 22.13 and `git` on
your `PATH`. Installers 01 and 02 are shell-only by design.

### Then open a new terminal

The installers append a marked block to your `~/.zshrc` and/or `~/.bashrc`, which the
session you installed from does not have. Open a new terminal (or `source ~/.zshrc`) and
check:

```bash
type qwe up projects                 # the three functions are loaded
projects-picker --list               # the TUI's non-interactive mode
deepeco                              # peak/off-peak status + price table
gitcraque --version
surf-free-skill "test query"         # web search with no API key at all
ls -l ~/.claude-deepseek/skills/     # the three surf-* links must be here
```

That last line is the one worth checking: if those links are missing, `deepclaude` cannot
see the research skills — see [Stop 4](#stop-4--the-agent-stops-guessing-surf-skill).

---

# The journey

One real task, end to end: *add rate limiting to an Express API*. Each stop introduces the
tool that serves it, with install and configuration inline.

## Stop 0 — the surface you watch it on (Ghostty)

An agent session is a firehose of streamed text, and the terminal is the first thing that
breaks.

```bash
./install.sh 02
```

The installer picks the right route — Homebrew cask on macOS; on Linux the
`mkasberg/ghostty-ubuntu` PPA (Ubuntu/Pop/Mint), `pacman` (Arch), `dnf copr pgdev/ghostty`
(Fedora), `zypper` (openSUSE), or `snap --classic` as a fallback — installs JetBrainsMono
Nerd Font, writes `~/.config/ghostty/config.ghostty` plus `themes/dracula`, validates the result
against the binary, and — **on Linux** — reloads your running instance with `SIGUSR2` so you
lose no open panes. On macOS nothing is signalled: reload by hand with `Ctrl+Shift+,`. It
also rewrites `shell-integration` to `bash` or `fish` when that is your login shell; every
other shell (zsh included) keeps the payload's `shell-integration = zsh`, so on an
uncommon shell set that key yourself. On Fedora it
installs `dnf-plugins-core` first, because `dnf copr` is a plugin and Server/minimal/container
images ship without it.

### The settings that exist for agent work

```ini
scrollback-limit = 100000000
```

**The unit is BYTES, not lines** — the single most misread key in Ghostty. The 1.3.x default
is `10000000` (10 MB); this is 100 MB per surface, because a long agent session genuinely
produces that much and you want the error from an hour ago still scrollable. Allocation is
lazy (ring buffer), so it costs what you actually printed. A "recommended" `1000000` you may
see in tuning posts is *ten times smaller than the default* and would truncate the session
you most need to read.

```ini
background-opacity = 1.0
background-blur = 0
cursor-style-blink = false
```

No per-frame alpha compositing: transparency looks nice and makes the compositor work on
every frame of a streaming log. `background-blur = 0` is a real key and a no-op without
transparency — it is explicit so it never gets switched on by accident. A blinking cursor
wakes the redraw loop roughly twice a second, forever. **The key is `cursor-style-blink`** —
`cursor-blink` does not exist in 1.3.1 and Ghostty rejects the file with `unknown field`,
exactly the typo that costs twenty minutes if you do not validate.

```ini
theme = dracula
```

Lowercase, deliberately: the official [dracula/ghostty](https://github.com/dracula/ghostty)
port that the installer drops in `~/.config/ghostty/themes/dracula`. Ghostty also has a
**built-in** theme called `Dracula`, capital D — a *different* theme with different colours.
The casing is the whole difference.

The rest of the 27 keys are ordinary ergonomics — `window-theme = ghostty`,
`gtk-titlebar-style = tabs`, `font-family = JetBrainsMono Nerd Font`, `font-size = 12`,
`window-padding-x/y = 6` — with two worth naming: `confirm-close-surface = true` asks before
killing a surface with a live process, which protects a tab running an agent, and
`gtk-single-instance = true` puts new windows in the same process, so a new window inherits
the *loaded* config instead of re-reading the file. `cursor-click-to-move = true` (click
anywhere on the prompt line to move the cursor) works only through `shell-integration`,
which is why the installer rewrites that key to your login shell.

### Three rules that will save you an afternoon

**1. Ghostty does not watch its config file** (issue #449, closed `wontfix`). Applying a
change means reloading — never restarting, which costs you every scrollback buffer you were
keeping:

```bash
# inside a Ghostty window:  Ctrl+Shift+,
pkill -USR2 -x -U "$(id -u)" ghostty     # from anywhere (PR #7759)
```

That is the installer's own command. The `-U "$(id -u)"` filter matters on a shared machine:
without it the first matching PID may belong to another user, and you get a silent `EPERM`
instead of a reload.

**2. Validate before you reload**, with exactly this syntax — an `=`, and an **absolute**
path:

```bash
ghostty +validate-config --config-file=/home/you/.config/ghostty/config.ghostty
```

The space-separated form and the `~` form both **exit 1 silently** — no output, no error.
You will blame your config when the invocation was the problem. Exit 0 with no warnings
means you are good; a bad key is reported as `unknown field` with its line number.

**3. Some keys need a new window.** `gtk-titlebar-style` and `window-theme` apply to windows
created *after* the reload; `gtk-single-instance` only on a full app restart. A reload that
"did nothing" is usually this.

Inspect what is live with `ghostty +show-config`, `+list-keybinds`, `+list-themes`. There is
no `+list-config` in 1.3.1, whatever autocomplete-driven memory suggests.

### The keybinds, and what they cost you

| Key | Action |
|---|---|
| `Ctrl+T` / `Ctrl+R` | new tab / rename tab |
| `Ctrl+←/→/↑/↓` | new split in that direction |
| `Ctrl+Alt+←/→/↑/↓` | navigate between splits (Ghostty default) |
| `Ctrl+W` | close surface (asks first if something is running) |
| `Ctrl+8/4/2/6` | resize the divider up / left / down / right |
| `Ctrl+Shift+,` | reload config (Ghostty default) |

**Know what you are giving up.** The terminal captures these, so zsh never sees them:
`Ctrl+R` (reverse history search), `Ctrl+W` (backward-kill-word) and `Ctrl+←/→` (word jump)
stop working in the shell. A deliberate trade — tabs and splits get constant use when
supervising agents — but a trade; if you live in `Ctrl+R`, delete those `keybind` lines
before reloading.

One last gotcha the installer handles: a legacy `~/.config/ghostty/config` file (the
pre-1.2.3 name) is **still read**, merged with `config.ghostty`, and **wins on conflict** —
it is moved to `config.pre-aula-bak-<timestamp>` instead of silently overriding half your
settings. Nothing is ever deleted.

## Stop 1 — land in the repo (projects)

```bash
./install.sh 01
# then open a NEW terminal — `projects` is a shell function, and the installer
# runs in a child process that cannot define functions in your current shell
projects
```

A TUI (Ink 5.2.1 + React 18.3.1) lists the directories in `~/Projects`, newest-modified
first with a relative-time hint. Type to filter, `↑↓` through a 10-item sliding window,
`Enter` to open, `Esc` or `Ctrl+C` to cancel without moving. Enter on an empty filter result
falls back to `~/Projects` itself. Projects elsewhere? `export PROJECTS_DIR=/srv/code`.

**The architectural detail worth stealing.** A TUI cannot `cd` your shell — a child process
cannot change its parent's directory. So the picker **renders the interface to stderr and
writes only the chosen path to stdout**:

```js
render(<App/>, { stdout: process.stderr });   // the UI goes to fd 2
fs.writeSync(1, target + "\n");               // fd 1 carries the answer
```

which lets the shell function capture stdout and move only if the picker actually chose
something. The version that ships checks the exit status first, because `Esc` exits `1` with
an empty stdout and a bare `cd -- ""` would land you in `$HOME`:

```bash
projects() {
  local d
  d="$(projects-picker)" || return $?   # Esc/Ctrl+C: exit non-zero, do not move
  cd -- "$d" || return 1                # `--` survives a path starting with `-`
}
```

Same convention `fzf` uses, and the reason every banner in `comandos.sh` also goes to
stderr: one stray `echo` on stdout and `cd` receives a banner instead of a path.

**Its two dependencies are load-bearing.** React stays at **18.3.1** because `ink` 5.2.1
drives `react-reconciler` against the React 18 ABI — React 19 breaks it at *runtime*, not at
install time, which is worse. Never bump one without the other.

Which is also why the install is **`npm ci --omit=dev`, never `npm install`**: `npm ci`
reproduces the lockfile exactly (`ink` 5.2.1, `react` 18.3.1 — the versions this was tested
against), while `npm install` is free to resolve the declared `"ink": "^5.2.0"` to any newer
5.x that has shipped since. The picker's entire UI is that one dependency.

The bundle is built with `esbuild --bundle --platform=node --format=esm --packages=external
--banner:js="#!/usr/bin/env node"`. ESM is mandatory — ink's reconciler uses top-level
`await` — and the shebang must come from `--banner`, because esbuild treats one in the
source as a stray comment and moves it off line 1.

Finally, `projects-picker --list` prints the names with no TUI at all: what the installer's
smoke test uses, and what you should use when scripting.

## Stop 2 — an isolated place to work (qwe)

The agent is about to rewrite files. Not on your branch.

```bash
cd ~/Projects/my-api
qwe add-rate-limit
```

That creates a git **worktree** at `../my-api.worktrees/add-rate-limit` — a *sibling*
directory, never nested inside the repo it belongs to, so it never shows up in `git status`
and never confuses editors, watchers or your own `rg` invocations — checks out a new branch
there, and `cd`s you in. Your original working tree is untouched, still on its branch, still
with your uncommitted edits.

```bash
qwe                              # no name: prompts (Enter accepts ai-task-<epoch>)
qwe add-rate-limit               # create and enter
qwe add-rate-limit -a deepclaude # ...and launch the DeepSeek-backed agent inside it
qwe -a claude                    # prompt for a name, launch official Claude Code
CLAUDE_CONTA=deepclaude qwe fix  # same as -a, via environment
```

Without `-a` no agent starts at all — it is purely "create a worktree and enter it", which
is useful on its own. Valid accounts in this version are `deepclaude` (installer 03) and
`claude` (the official CLI). Three decisions inside that function are worth knowing:

- **The account is resolved *before* the worktree is created**, so a typo in `-a` or a
  missing launcher fails immediately instead of leaving an orphan branch and directory.
- **The branch name is validated** with `git check-ref-format refs/heads/<name>` before
  anything is created; the interactive prompt loops until you give a legal one.
- **Where you came from is recorded in git config** — `branch.<b>.origdir` (the repo root
  you ran `qwe` from) and `branch.<b>.origbranch` (the branch you were on) — so closing the
  worktree later knows where to return and what to merge into.

> **Both agent accounts run with permission prompts disabled.** `qwe -a claude` runs
> `claude --dangerously-skip-permissions --effort max`, and `deepclaude` does the same. The
> agent will edit files and run commands without asking. That is exactly why every task gets
> its own worktree and its own branch: the blast radius is one disposable directory, and
> `git diff` against the parent branch is the review. Do not point either account at a tree
> whose contents you are not prepared to see rewritten.

`comandos.sh` works in **both zsh and bash** (Linux, macOS, Git Bash): no arrays, no `read
"var?prompt"`, prompts are `printf` + `read -r`. Keep that constraint if you extend it.
Tearing the worktree down again is [Stop 6](#stop-6--come-back-and-merge-up).

## Stop 3 — the agent (deepclaude)

```bash
./install.sh 03
```

This installs Claude Code if missing (official native installer `curl -fsSL
https://claude.ai/install.sh | bash`, `npm i -g @anthropic-ai/claude-code` as fallback),
publishes two commands to `~/.local/bin`, installs the `/eco` slash command into
`~/.claude-deepseek/commands/eco.md`, writes the pricing window to
`~/.config/aula-dev/deepeco.conf`, and asks for your **DeepSeek API key** — create one at
<https://platform.deepseek.com/api_keys>.

The key is **validated against the live API before it is stored**: `GET
https://api.deepseek.com/user/balance`, which costs no tokens — 200 means valid and prints
your balance, 401 means invalid and it asks again, three attempts, then it gives up without
writing anything. It is typed with terminal echo off, so it never reaches your screen or
your shell history, and lands in `~/.claude-deepseek/deepseek.key` at `chmod 600` inside a
`chmod 700` directory. A re-run re-validates the stored key and only redoes the setup if it
fails. Change it later with `deepclaude --setup-key`.

Now, from the worktree in Stop 2:

```bash
qwe add-rate-limit -a deepclaude
```

You get the **official Claude Code binary** — the whole harness, with its tools, subagents,
skills and slash commands — talking to **DeepSeek's own Anthropic-compatible endpoint** at
`https://api.deepseek.com/anthropic`, in an isolated config directory
(`~/.claude-deepseek`) that never touches your real Claude Code setup. No fork, no proxy, no
patched CLI: it is an environment prefix and an `exec`.

### The six model pins, and why a missing one is worse than an error

The endpoint maps Anthropic model ids to DeepSeek models **by prefix**:

| You send | DeepSeek runs |
|---|---|
| `claude-opus-*` | `deepseek-v4-pro` |
| `claude-sonnet-*` | `deepseek-v4-flash` |
| `claude-haiku-*` | `deepseek-v4-flash` |

The CLI calls its main agent "sonnet" on several internal routes. Pin only the opus slot and
the main agent silently runs on Flash — **nothing errors**. You get a different model than
you think, at a different price and quality, with no signal at all.

Worse: per DeepSeek's own docs a **typo in a model id does not error either** — the
`/anthropic` route "will automatically map it to the `deepseek-v4-flash` model", so a
misspelled id returns HTTP 200 on the cheap model. There is no failure to notice. That is
why `deepclaude` sets all six slots and is the **single source of truth**: `qwe -a
deepclaude` delegates here rather than re-declaring anything. The launcher prefixes the whole
environment to the command, so its values win over anything exported in your shell and
nothing leaks back out — which is exactly why a second copy of these pins somewhere else is
a liability rather than a safety net: it drifts, and the drift is invisible.

```bash
env -u ANTHROPIC_API_KEY \
  CLAUDE_CONFIG_DIR=~/.claude-deepseek \
  ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic \
  ANTHROPIC_AUTH_TOKEN=<your key> \
  ANTHROPIC_MODEL=deepseek-v4-flash[1m] \
  ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-flash[1m] \
  ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-flash[1m] \
  ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash[1m] \
  ANTHROPIC_DEFAULT_FABLE_MODEL=deepseek-v4-pro[1m] \
  CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash[1m] \
  CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576 \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432 \
  claude --dangerously-skip-permissions --effort max
```

Details in there that are not decoration:

- **`env -u ANTHROPIC_API_KEY` removes the variable rather than blanking it.**
  `ANTHROPIC_AUTH_TOKEN` already wins on precedence, but an inherited *empty*
  `ANTHROPIC_API_KEY` is exactly the ambiguity that produces a 401 you cannot explain.
- **The env is prefixed to the command**, so it exists in that process only and nothing
  leaks into your shell. Which also means: do not export any of this in your rc file.
- **`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1048576`** because the CLI does not recognise
  `deepseek-*` as a Claude model and would assume a 200K window, firing auto-compact at a
  fifth of what the model holds.
- **`CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432`** — 75% of 1M, the value DeepSeek prescribes in
  its own Claude Code guide. Declaring only the window is not enough: output can reach 384K
  tokens and must fit in what is left.
- **Only two model ids are valid here**: `deepseek-v4-flash` and `deepseek-v4-pro`, with an
  optional `[1m]` suffix for the 1M-context variant. Dated ids (`deepseek-v4-pro-0813`) and
  gateway-prefixed ids (`deepseek/...`) **do not exist on this API** — those are OpenRouter
  strings, and here they quietly remap to Flash.

### Why Flash by default, and how to reach Pro

The default is `deepseek-v4-flash[1m]`, currently the 0731 build, and it is not the cheap
fallback the name suggests. Against the **V4 Pro Preview** it wins on Terminal Bench 2.1
(82.7 vs 72.1) and DeepSWE (54.4 vs 12.8), at roughly 3× cheaper and 1.7× faster. Read that comparison carefully — it is against the
*Preview*. Against the **GA Pro-0813** build the ranking is the ordinary one, and Pro leads
every row:

| Benchmark (max reasoning effort) | Flash-0731 | Pro-0813 |
|---|---|---|
| Terminal Bench 2.1 | 82.7% | 87.9% |
| DSBench-FullStack | 68.7% | 71.1% |
| DSBench-Hard | 59.6% | 67.2% |
| NL2Repo | 54.2% | 61.5% |
| Cybergym | 76.7% | 83.3% |
| Toolathlon-Verified | 70.3% | 74.1% |

Which is exactly what `--pro` and `/model fable` are for — no restart needed:

```bash
deepclaude                          # V4 Flash session (the class default)
deepclaude --pro                    # whole session on V4 Pro — heavy refactors
deepclaude -p "summarize the repo"  # any claude flag passes straight through
```

```
/model fable        # switch this session to V4 Pro
/model sonnet       # ...and back to V4 Flash
/status             # which endpoint is actually in use
/eco                # the price window, without leaving the session
```

(`fable` is the slot `deepclaude` points at Pro — that is the whole trick.) For the record:
Pro is 1.6T total parameters / 49B active, Flash-0731 is 284B / 13B; both 1M context and
384K max output, trained with Muon over 32T tokens, MoE experts in FP4 and non-experts in
FP8, hybrid CSA (m=4) and HCA (m'=128) attention.

### What you give up — read this before sending it your employer's code

| Feature | Status on the DeepSeek endpoint |
|---|---|
| Vision / multimodal | **Gone.** The layer rejects `type="image"` and `type="document"`. |
| MCP | **Gone.** `mcp_servers`, `mcp_tool_use`, `mcp_tool_result` are ignored or refused. |
| `cache_control` | **Ignored.** No manual prompt-cache breakpoints. |
| `thinking.budget_tokens` | Accepted, then **ignored** — DeepSeek uses a qualitative `reasoning_effort`. Can surface as `API Error: 400 thinking options type cannot be disabled when reasoning_effort is set`. |
| Parallel tool calls | Often **serialize** in practice: lower cost, higher wall-clock. |
| `code_execution_tool_result`, `container*` | Unsupported. |
| `web_search_tool_result` | **Still works** — routed to DeepSeek's own engine. |

Two risks that are not feature-shaped. **Hallucination**: V4 Pro scored a 94% hallucination
propensity on AA-Omniscience, so treat confident factual claims from this stack as unverified
by default — inside an agent loop an invented package name becomes a real install attempt and
a real rabbit hole. Precisely why [Stop 4](#stop-4--the-agent-stops-guessing-surf-skill)
exists. **Data retention**: sending proprietary code to public DeepSeek infrastructure means
you no longer have Anthropic's zero-data-retention guarantees. Know your employer's policy
before you point `qwe -a deepclaude` at a work repo; that is a decision for a human, not for
a shell script.

Known workaround for the "tool call black hole" — the agent reports edits, the disk
disagrees:

```bash
export CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING=0
```

## Stop 4 — the agent stops guessing (surf-skill)

You ask for rate limiting on Express. The model answers from training data, and
`express-rate-limit` changed its options object after that data was collected. This is the
failure mode that costs the most time, because the output *looks* right.

**surf-skill** is a separate project by the same author: autonomous web research that runs
*inside a CLI*, not inside the agent's context window. Asking a coding agent to research well
means asking it to decompose a question, write category-diverse queries, fan them out, read
the harvest, notice the gaps and search again — all while holding your actual task in the
same context. It burns tokens and gives different results every run. surf-skill makes that
loop **code**: the agent writes a four-line brief and gets a cited answer.
<https://github.com/frederico-kluser/surf-skill> · npm `surf-skill` v7.0.0, MIT, Node ≥ 18,
**zero npm dependencies**.

```
1 PLAN        an LLM (DeepSeek V4 Pro via OpenRouter) turns the brief into sub-questions
              plus a category-diverse query array
2 SEARCH      all queries at once, bounded worker pool: tavily → parallel → brave → keyless,
              multi-key rotation, per-key cooldowns
3 ANALYZE     (unlimit only) what is still open, and the queries that would close it
4 LOOP        (unlimit only) open points become round N+1
5 SYNTHESIZE  the answer in the shape you asked for, cited against a numbered source index

surf-search-normal  = 1 → 2 → 5 (2 LLM calls, exactly one round)
surf-search-unlimit = the full loop
```

### Install, and the bridge that makes it visible

```bash
./install.sh 04
```

That runs `npm i -g surf-skill` (plus GitCraque, [Stop
5](#stop-5--read-the-history-gitcraque)) and then does the thing this repo exists to do.
surf-skill's postinstall symlinks its three skills into the four harness directories it
knows about — `~/.agents/skills/`, `~/.claude/skills/`, `~/.codex/skills/`,
`~/.pi/agent/skills/`. But `deepclaude` runs Claude Code with
`CLAUDE_CONFIG_DIR=~/.claude-deepseek`, and personal skills are read from
`<CLAUDE_CONFIG_DIR>/skills` — which is **not** in that list.

Without a bridge the skills sit on disk, the `surf-*` binaries sit on your `PATH`,
`surf-search-normal` works if you type it — and the class's main agent never learns the
capability exists, with no error explaining why. So the installer mirrors them:

```
~/.claude-deepseek/skills/surf-research-skill -> <npm root -g>/surf-skill
~/.claude-deepseek/skills/surf-plan-skill     -> <npm root -g>/surf-skill/skills/surf-plan-skill
~/.claude-deepseek/skills/surf-free-skill     -> <npm root -g>/surf-skill/skills/surf-free-skill
```

(`surf-research-skill` points at the package root because that is where its `SKILL.md`
lives.) On MSYS/Git Bash without symlink privileges it copies instead; the PowerShell
installer tries a junction first, which needs no admin rights. A **real directory** at one of those paths is left alone with a warning. The test is
"is this a symlink?", not "is this ours?" — so a symlink you made yourself pointing at your
own checkout does get replaced. Keep a hand-rolled override as a real directory. The bridge resolves through `npm root -g`, so if you move the npm prefix later, re-run
this installer to make the links follow.

It also handles the other silent failure of `npm i -g`: if the global npm prefix is not
writable by your user (distro-packaged Node writing to `/usr/lib/node_modules`) it does
**not** reach for `sudo`, which would install for root and disappear from your `PATH`. It
runs `npm config set prefix ~/.local` instead — a global npm setting, so every future
`npm i -g` lands there too, next to everything else this repo installs.

### Configure: keys

The installer offers the wizard at the end; skipping is safe, since `surf-free-skill` needs
no key at all.

```bash
surf                            # wizard: Tavily / Parallel / Brave / OpenRouter
surf-research-skill ai-setup    # just the OpenRouter key that powers the loop
surf-research-skill ai-setup --key sk-or-v1-...        # non-interactive
surf-research-skill keys add --provider tavily tvly-AAA tvly-BBB tvly-CCC
surf-research-skill keys list   # masked
surf doctor                     # what is configured and what is ready
```

Where the keys come from: **OpenRouter** <https://openrouter.ai/keys> (the one surf-ai plans
and synthesizes with), **Tavily** <https://tavily.com>, **Parallel AI** <https://parallel.ai>,
**Brave Search API** <https://brave.com/search/api/>.

Keys are **live-validated** as you paste them — valid ones saved, invalid ones not — and
validating the OpenRouter key is free (key introspection, zero tokens, zero credits).
Everything persists to `~/.config/surf/keys.json` (`chmod 600`), the only file on disk that
ever holds a key. You can add several keys per provider: rotation is automatic on
`401`/`403`/`402` or persistent `5xx`, burned keys auto-reset on the 1st of the next month,
and a `429` earns a cooldown that persists across runs. The LLM has its own fallback chain:
`v4-pro → v4-flash-0731 → v4-flash → v3.2 → chat-v3.1`.

Nothing is a hard blocker; the degrade path is the design:

| You have | What happens |
|---|---|
| Search keys + OpenRouter key | The full loop: plan → fan-out → analyze → synthesize |
| Search keys only | Real searches, cited evidence brief, no synthesis — labelled `⚠ Degraded mode`. **Exit 0. A success, not an error — do not retry it.** |
| OpenRouter key only | Keyless tier (Wikipedia + DuckDuckGo) plus synthesis |
| Neither | `surf-free-skill "query"` — zero setup, no account anywhere |

### Configure: per project (do not skip this)

```bash
cd ~/Projects/my-api
surf-research-skill project-config
```

Once per repository, and the step people forget — its failure mode looks exactly like "surf
is broken". Research calls take longer than a normal shell command, and most harnesses have a bash
timeout that will kill them mid-flight (Pi core is the exception — it applies none). The npm postinstall writes **no** timeout config
anywhere; this is always a separate, per-project step:

| Harness | Default bash timeout | What `project-config` writes |
|---|---|---|
| Claude Code | 120 s (the model may request up to 600 s) | `.claude/settings.local.json` with `BASH_DEFAULT_TIMEOUT_MS=300000`, `BASH_MAX_TIMEOUT_MS=600000` |
| GitHub Copilot CLI | **30 s** — the most fragile of the three; **required** here | `.github/copilot-hooks.json` with `{"timeoutSec":300}` |
| Pi Coding Agent | **none** in core — the best harness for `unlimit` | `.pi/settings.json` |

For `surf-search-unlimit` on Claude Code, pass `timeout: 600000` on the Bash call explicitly.
`surf-search-normal` falls back to a 110 s self-budget when it cannot detect a harness;
`--budget-ms N` overrides it (`0` = unlimited). `surf-search-unlimit` already runs with no
self-budget. The `--no-budget` flag (= `SURF_NO_TIMEOUT=1`) belongs to the *manual* toolbox
commands — `search`, `search-parallel` and friends — which otherwise self-abort at a 30 s
guess on a no-limit harness.

### Use it

```bash
surf-free-skill "rate limiting"                          # no key needed

surf-search-normal "does express-rate-limit v8 still accept the windowMs option?" \
  --task "adding rate limiting to an Express 5 API" \
  --goal "know the exact options object shape for the current major" \
  --insights "I believe windowMs and max are still top-level"

surf-search-unlimit "<question>" --max-rounds 6
```

Or, inside the `deepclaude` session from Stop 3, just ask: *"research the current
express-rate-limit API before you write anything"* — or *"make a plan for adding rate
limiting"*, which triggers `surf-plan-skill`: it reads the project, runs the research, asks a
handful of research-backed questions, and only then writes a plan. Research there is gated,
not optional.

**The brief is the whole job** — these four flags separate a useful answer from a Wikipedia
summary:

| Flag | What goes in it | Why it changes the answer |
|---|---|---|
| `--task` | the work in progress | the planner drops queries that do not move it forward |
| `--goal` | the decision this feeds | becomes the objective the synthesis is graded against |
| `--insights` | what you already believe | the planner writes queries that could **falsify** each belief |
| `--deliverable` | the output shape you need | the synthesis matches it instead of writing an essay |

Long briefs go in a file: `--brief-file brief.json`.

| | `surf-search-normal` | `surf-search-unlimit` |
|---|---|---|
| Rounds | exactly 1 | until resolved (default cap 6, `--max-rounds` up to 50) |
| Time | fitted inside the harness bash timeout | no self-imposed deadline |
| Typical | 45–110 s · ~$0.01–0.03 | 2–15 min · ~$0.03–0.15 |

Exit codes: `0` an answer (possibly degraded) · `1` nothing retrieved at all · `2` usage
error · `143` the harness killed it.

It is also a Node library — `import { search, searchParallel, extract, research } from
'surf-skill'` and `import { runSurfAi } from 'surf-skill/ai'` — server-side only, because
Tavily, Parallel and OpenRouter send no CORS headers for browser origins.

### Security

Keys are only ever persisted to `~/.config/surf/keys.json` (`chmod 600`). CLI mode reads
search keys from there and nowhere else; `OPENROUTER_API_KEY` is the single environment
exception and is used in memory only. Library mode also reads env and `.env`, deliberately,
for serverless and CI.

**Prompt injection is mitigated, not solved.** surf-ai feeds retrieved page text to an LLM,
and every prompt carries an explicit rule that search results are untrusted data whose
instructions are content to report on, never to follow — a mitigation, not a guarantee, so
never let an agent act on a synthesized answer without reading it. And **your brief goes to
OpenRouter**: `--task`, `--goal` and `--insights` are sent as prompt text, so no secrets, no
customer data, no proprietary source in them.

## Stop 5 — read the history (GitCraque)

The agent has been committing for twenty minutes. `git log --oneline` across a worktree and a
main branch is a poor way to see what happened.

**GitCraque** is a desktop Git client with **no Electron**: a pure Node.js backend
(`node:http`) drives the `git` binary through `child_process` — argv always as an array,
never a shell string — and serves a React 19 + Vite SPA to your browser. The backend has
**exactly one dependency**: `ws`. Separate project by the same author:
<https://github.com/frederico-kluser/GitCraque> (MIT).

### Install

`./install.sh 04` installs it, or by hand:

```bash
npm install -g gitcraque
cd ~/Projects/my-api && gitcraque
npx gitcraque                       # or no install at all
```

**Node ≥ 22.13 and `git` on your `PATH`. Linux and macOS.** The floor is not arbitrary: the
project memory uses `node:sqlite`, which only drops the `--experimental-sqlite` flag at
22.13. The installer checks that floor *separately* from surf-skill's `≥ 18` and, if your
Node is older, **skips GitCraque with a warning instead of failing the run** — you still get
surf-skill. Raise Node (`nvm install 24`) and re-run `./install.sh 04`; it is idempotent.

One trap worth stating plainly: **install it from npm, not from the GitHub URL.**
`npm i github:frederico-kluser/GitCraque` does not fail — it exits `0` and looks fine — but
the published package is what ships the SPA pre-built, and that build only runs on
`npm pack`. Installed straight from the repo there is no `web/dist`, so the server starts and
has no interface to serve. From source it is clone + `npm run build`.

```bash
gitcraque                    # the repo you are standing in
gitcraque ~/code/project     # or point at a path, like git -C
gitcraque --repo <path>
gitcraque --port 5271
gitcraque --no-open          # do not open the browser
gitcraque --help
gitcraque --version
```

Default port 5271; if it is taken it tries the next ten and names the winner in the banner,
so several repositories stay open at once without hand-assigned ports. Started outside a
repository, the screen is the **picker**, not an error: recents, a sweep of the machine's
usual folders (`Projects`, `code`, `/opt`, `/srv`), a folder browser with breadcrumbs, and a
`git init` for wherever you stand. Switch repos later with the Open button or `⌘K`.

### What it is actually good at here

- **Worktrees without checkout** — the natural pair for what `qwe` created. Click a worktree
  label and the **server** runs `process.chdir()` to its absolute path and emits a WebSocket
  signal. No `git checkout` happens; nobody's working tree is touched. You read the agent's
  branch while your own edits sit undisturbed in the main tree.
- **The history graph.** The backend runs `git log --all --topo-order`; the front-end
  computes each commit's `(X, Y)` itself — `Y` is topological order, `X` comes from a
  heuristic separating *branch children* from *merge children* so routes never overlap. The
  drawing is **hand-written SVG** (`<circle>` commits, cubic-Bézier `<path>` branches and
  merges) with window virtualization. No gitgraph library.
- **Drag-and-drop with intent** (`@dnd-kit/core`). A commit onto a branch label proposes a
  `cherry-pick`; a branch onto a branch offers `merge` or `rebase`. The raw command is shown
  before anything runs, and anything that rewrites history requires **press-and-hold**
  confirmation — the button only gives way if you keep holding.
- **Graphical squash.** It injects `GIT_SEQUENCE_EDITOR` pointing at a proxy-editor script
  that rewrites the `git-rebase-todo` git generated (`pick` → `squash`, first line stays
  `pick`) and exits 0. Zero terminal emulation; nobody opens `vim` in your face.
- **A push that never hangs.** Node injects `GIT_ASKPASS` pointing at its own script and the
  secret travels over a unix socket with a single-use nonce — never in the git process
  environment, never in argv, never on disk.
- **Tab-discard recovery.** It handles `visibilitychange`, `resume` and `pageshow(persisted)`
  and snapshots the view when the tab **hides**, because `beforeunload` and `unload` do not
  fire when a browser discards a tab.

### Security posture

The server runs `git` commands on your machine. It **listens on `127.0.0.1` by default**
— `--host` can change that, and the default is the one you want — and
refuses requests whose `Host` or `Origin` come from anywhere else. It **must not be exposed
to a network** — no reverse proxy, no `0.0.0.0`, no forwarding the port out of a container
"just for a minute so a colleague can look". Treat it like an unauthenticated shell bound to
localhost, because functionally that is close to what it is.

## Stop 6 — come back and merge (up)

```bash
up
```

From inside a worktree, `up` returns you to the **main repository root**; from a subdirectory
of the main repo, to the repo root; already at the main repo root, or outside git entirely,
it is plain `cd ..`. Then merge like an adult, having read the graph:

```bash
git merge add-rate-limit
git worktree remove ../my-api.worktrees/add-rate-limit
git branch -D add-rate-limit
```

There is no teardown command by design — deleting work should be a conscious act.

The implementation is three lines of shell and two hard-won details. It takes the **first
entry of `git worktree list --porcelain`** — git guarantees the main worktree is listed first
— rather than `--git-common-dir`, which looks like the right answer and returns a *relative*
path from a subdirectory. And it normalises both paths with `cd` + `pwd -P` before comparing:
in Git Bash git prints `C:/Users/...` while `$PWD` is `/c/Users/...`, which would never
compare equal, and on macOS `/tmp` is a symlink to `/private/tmp`, so a symlinked cwd diverges
from the physical path git reports.

## Stop 7 — the cheap window (deepeco)

```bash
deepeco            # banner + status + price table
deepeco --short    # status + table (what deepclaude prints at launch)
/eco               # inside a deepclaude session: runs the FULL `deepeco` and has
                   # the model read the table back to you in a sentence or two
```

`deepeco` prints whether the DeepSeek API is in its **peak** or **off-peak** window right
now, when that changes, and what each model costs in each. Because `deepclaude` runs
`deepeco --short` at launch, every session opens by telling you what it is about to cost.

Since **2026-08-16 16:00 UTC** DeepSeek prices by time of day. The windows are defined in
**UTC by the API server's clock** — a good way to be wrong by three hours — so `deepeco`
reads your offset with `date +%z` and prints everything in your local zone.

| Window | UTC | Brazil (UTC−3) | Price |
|---|---|---|---|
| **Peak** | 01:00–04:00 and 06:00–10:00 | 22:00–01:00 and 03:00–07:00 | 2× |
| **Off-peak** | the other 17 hours | 01:00–03:00 and 07:00–22:00 | half of peak, uniform across models |

Per 1M tokens (cache hit / cache miss / output):

| Model | Off-peak | Peak |
|---|---|---|
| `deepseek-v4-flash` | $0.007 / $0.22 / $0.66 | $0.014 / $0.44 / $1.32 |
| `deepseek-v4-pro` | $0.022 / $0.66 / $1.98 | $0.044 / $1.32 / $3.96 |

Source: <https://api-docs.deepseek.com/quick_start/pricing/>

**Be honest about what this is.** The old off-peak *discount* (16:30–00:30 UTC, 50% off chat
/ 75% off reasoner) ended on 2025-09-05, and what replaced it is structurally a **price
increase**: peak is roughly 4× the old flat rate, and even the new off-peak tariff costs more
than the flat rate that applied until 2026-08-15. "Off-peak" buys you the less bad half of a
more expensive schedule. `deepeco` is not a discount finder — it is a tool for not
accidentally paying double. The narrow good news for a Brazilian working day: **07:00–22:00
local falls entirely inside off-peak**, and the peaks land at night and in the small hours.

**Caveat:** the docs do not say whether the request's **start** or **completion** time counts
(under the 2025 policy it was completion), so near a boundary leave margin on long tasks — a
40-minute run started at 00:50 UTC is a gamble.

Window and prices live in `~/.config/aula-dev/deepeco.conf`, not in the script. When DeepSeek
changes policy, edit the conf (`ECO_ATIVO="0"` makes it report flat pricing; `DEEPECO_CONF=/path`
points elsewhere):

```ini
ECO_ATIVO="1"
ECO_PICOS_UTC="01:00-04:00 06:00-10:00"    # ⚠ MUST be chronological
ECO_PRECO_FLASH_ECONOMIA='$0.007 / $0.22 / $0.66'
```

`ECO_PICOS_UTC` must be chronological because `deepeco` derives off-peak as "end of one peak
→ start of the next", and tariff cells stay pure ASCII because the table aligns its columns by
character count. The file is piped through `tr -d '\r'` before sourcing, so a Windows clone
with `core.autocrlf=true` cannot kill the script with `$'\r': command not found`.

---

# Reference

## Where everything lands

| Path | What |
|---|---|
| `~/.local/bin/` | `projects-picker`, `deepclaude`, `deepeco` (and npm globals, if the prefix moved) |
| `~/.local/share/projects-picker/` | the TUI and its `node_modules` |
| `~/.local/share/fonts/JetBrainsMonoNerdFont/` | the Nerd Font, on Linux, if it was missing |
| `~/.config/aula-dev/comandos.sh` | `projects`, `qwe`, `up` |
| `~/.config/aula-dev/deepeco.conf` | peak/off-peak windows and prices |
| `~/.config/ghostty/config.ghostty` | terminal config (+ `themes/dracula`, + any `.bak-*`) |
| `~/.claude-deepseek/` | isolated Claude Code config (mode 700) |
| `~/.claude-deepseek/deepseek.key` | your DeepSeek key (mode 600) |
| `~/.claude-deepseek/commands/eco.md` | the `/eco` slash command |
| `~/.claude-deepseek/skills/` | the surf skills, bridged in for `deepclaude` |
| `~/.config/surf/keys.json` | surf-skill's keys (mode 600) |
| `~/.agents/skills/`, `~/.claude/skills/`, `~/.codex/skills/`, `~/.pi/agent/skills/` | surf-skill's own postinstall links — four directories covering five harnesses (`~/.agents/skills` serves both OpenCode and GitHub Copilot CLI) |
| `~/Projects/` | created if absent (that is where `projects` looks) |
| `~/.zshrc` / `~/.bashrc` | one marked block per concern, added idempotently |

The rc blocks are delimited by `# >>> aula-dev (...) >>>` / `# <<< aula-dev (...) <<<` —
`comandos da aula` from installer 01, `PATH ~/.local/bin` from 03, and `PATH npm global` from
04 when the npm bin directory is somewhere other than `~/.local/bin`. Deleting a block cleanly
uninstalls that piece. On macOS and Git Bash, where bash runs as a *login* shell and never
reads `~/.bashrc` on its own, installer 01 also chains `~/.bash_profile → ~/.bashrc` — but
only when a `~/.bash_profile` already exists. If you have none (common on a fresh Git Bash),
the block sits unread in `~/.bashrc` and `projects`/`qwe`/`up` come back "command not found".
Fix it by creating one:

```bash
printf '\n[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' >> ~/.bash_profile
```

## Commands

| Command | What it does |
|---|---|
| `projects` (`projects-picker --list`) | TUI picker over `~/Projects` / `$PROJECTS_DIR`, then `cd` |
| `qwe [branch] [-a deepclaude\|claude]` | sibling worktree, enter it, optionally launch an agent |
| `up` | worktree → main repo root; subdir → repo root; otherwise `cd ..` |
| `deepclaude [claude args]` · `--pro` · `--setup-key` · `--help` | Claude Code on V4 Flash · session on V4 Pro · key setup |
| `deepeco` / `deepeco --short` / `/eco` | peak/off-peak status + price table |
| `gitcraque [path]` · `--repo` · `--port` · `--no-open` | the Git client, in your browser, on 127.0.0.1 |
| `surf-free-skill "q"` | keyless web search |
| `surf-search-normal "q" --task … --goal …` | one research round, cited |
| `surf-search-unlimit "q" --max-rounds 6` | rounds until resolved |
| `surf` · `surf doctor` · `surf-research-skill keys list` | key wizard · diagnostics · stored keys |
| `surf-research-skill project-config` | per-project harness timeout config |

## deepclaude environment overrides

All optional; the defaults are what the class uses. Set them in the environment for a one-off
run — not in your rc file, where a stale value would outlive the reason you set it.

| Variable | Default |
|---|---|
| `DEEPCLAUDE_DIR` | `~/.claude-deepseek` |
| `DEEPCLAUDE_API_KEY` | `<dir>/deepseek.key` |
| `DEEPCLAUDE_MODEL` | `deepseek-v4-flash[1m]` |
| `DEEPCLAUDE_HAIKU_MODEL` | same as the main model |
| `DEEPCLAUDE_FABLE_MODEL` | `deepseek-v4-pro[1m]` |
| `DEEPCLAUDE_BASE_URL` | `https://api.deepseek.com/anthropic` |
| `DEEPCLAUDE_MAX_CONTEXT_TOKENS` | `1048576` |
| `DEEPCLAUDE_AUTO_COMPACT_WINDOW` | `786432` |

## Why the workflow is shaped like this: prompt caching

Vibe coding — Karpathy's term from February 2025, Collins Word of the Year 2025 — fails on
**context**, not on prompt wording. What makes it economically viable is prompt caching, and
caching obeys exactly one rule:

> **The strict prefix rule.** A request reuses prior work only if the text matches linearly
> and uninterrupted **from token zero**. A partial match in the middle is worth nothing.

The measurement that makes this concrete: four requests sharing a stable root reached a
**99.79%** aggregate hit rate; five requests carrying the same ~30,000 tokens but with a
**mutated first line** hit **0%**, and were slower. It is a latency rule as much as a cost
rule — time-to-first-token on a 128K-token prompt drops from ~13 s cold to under ~500 ms warm.

- **Order the prompt by volatility**: system prompt → tool schemas → inert RAG documents →
  conversation history → volatile user input. Timestamps and UUIDs go **last**, never first.
- **Never reorder retrieved chunks between calls** — RAG re-ranking is the classic cache
  killer: same tokens, different order, zero reuse. And never send `reasoning_content` back on
  the next turn.
- **`user_id` partitions the KV cache per user.** On a batch job over a shared corpus that
  means a 0% hit rate. Omit it and aggregate per-user stats in your own middleware.
- **TTLs differ by provider.** Anthropic: 5-minute ephemeral by default (1.25× write, 0.10×
  read), 1-hour option at 2.0× write, and `cache_read_input_tokens` does **not** count against
  ITPM limits on recent models. Gemini: LRU where the TTL is a **ceiling**, not a reservation.
  DeepSeek: context caching on disk, best-effort, hours to days, 64-token minimum block, hits
  landing on 128-token multiples; concurrency ceilings 2500 (Flash) / 500 (Pro), and crossing
  them returns HTTP 429.
- **Your harness decides most of this.** Aider is the disciplined case — just-in-time context
  plus `--cache-keepalive-pings`. Cline and Roo Code hydrate eagerly and inject volatile
  timestamps and directory trees **at the top**, dropping hit rates from ~90% to ~60%.

Note the interaction with Stop 3: on the DeepSeek endpoint `cache_control` is ignored, so you
cannot place breakpoints by hand. Ordering by volatility is not an optimisation there — it is
the only lever you have.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `projects` / `qwe` / `up`: command not found | You are in the shell that was open during install. Open a new terminal, or `source ~/.zshrc`. |
| `projects` prints a banner instead of changing directory | Something wrote to **stdout**. The picker's UI and all banners must go to stderr. |
| `04-agent-tools` says *"Node.js não encontrado"* right after `01` installed Node | On Linux, `01` installs Node with `nvm` inside its own subshell, so the parent run never sees it. Open a new terminal and run `./install.sh 04`. |
| On Git Bash the run stops after `01` with *"FECHE e REABRA o Git Bash"* | Expected: Node was just installed via winget. Close Git Bash, reopen it, run `./install.sh` again. |
| PowerShell refuses to run `install.ps1` | Unsigned scripts are blocked by default: `powershell -ExecutionPolicy Bypass -File .\install.ps1`. |
| Ghostty config "does nothing" | You restarted instead of reloading, or the key needs a **new window** (`gtk-titlebar-style`, `window-theme`). |
| `ghostty +validate-config` prints nothing, exits 1 | You used a space instead of `=`, or a `~` path. Use `--config-file=/absolute/path`. |
| Ghostty rejects the config: `unknown field` | Most likely `cursor-blink`; the real key is `cursor-style-blink`. |
| Your Ghostty settings are silently overridden | A legacy `~/.config/ghostty/config` exists and wins on conflict. Move it aside. |
| The agent seems dumber (or cheaper) than expected | A model pin is missing or misspelled — the endpoint remaps to Flash and returns 200. Check all six env vars from `deepclaude`. |
| `API Error: 400 thinking options type cannot be disabled when reasoning_effort is set` | `thinking.budget_tokens` on the DeepSeek endpoint. Drop it. |
| The agent claims it edited files, the disk disagrees | `export CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING=0` |
| Auto-compact fires far too early | `CLAUDE_CODE_MAX_CONTEXT_TOKENS` is missing; the CLI assumed 200K. |
| `gitcraque` was not installed | Node < 22.13 (`node:sqlite`). `nvm install 24`, then re-run `./install.sh 04`. |
| The agent cannot see the `surf-*` skills | The bridge into `~/.claude-deepseek/skills/` did not run, or a real directory sits at one of those paths. Re-run `./install.sh 04` and read the warnings. |
| `⚠ Degraded mode — no LLM synthesis` | No usable OpenRouter key. The searches ran; you have a cited evidence brief. **Exit 0 — a success.** Run `surf-research-skill ai-setup`. |
| surf calls die at 30 s or 120 s | Harness bash timeout. Run `surf-research-skill project-config` in that project. |
| `npm i -g` fails with EACCES | Do not `sudo`. `npm config set prefix ~/.local` — which is what installer 04 does for you. |

## Uninstall

There is no uninstall script; nothing here is hidden. Most of it lives in `$HOME`, with two
exceptions: Ghostty itself and, on Linux, the repository the package manager added for it.

```bash
# 01-commands
rm -rf ~/.local/share/projects-picker ~/.local/bin/projects-picker
rm -f  ~/.config/aula-dev/comandos.sh

# 02-ghostty — your previous config is in ~/.config/ghostty/*.bak-*
rm -f  ~/.config/ghostty/config.ghostty ~/.config/ghostty/themes/dracula
rm -rf ~/.local/share/fonts/JetBrainsMonoNerdFont   # then: fc-cache -f

# 03-deepclaude — your official Claude Code install was never touched
rm -f  ~/.local/bin/deepclaude ~/.local/bin/deepeco
rm -rf ~/.claude-deepseek        # ⚠ includes the DeepSeek key and this account's history
rm -f  ~/.config/aula-dev/deepeco.conf

# 04-agent-tools
npm rm -g gitcraque surf-skill   # note: npm 7+ no longer runs uninstall lifecycle
                                 # scripts, so surf-skill's own symlinks in
                                 # ~/.agents ~/.claude ~/.codex ~/.pi survive — broken.
                                 # Remove them yourself:
                                 #   rm -f ~/.{agents,claude,codex}/skills/surf-*-skill
                                 #   rm -f ~/.pi/agent/skills/surf-*-skill
# The bridge into deepclaude. -rf, not -f: on Windows/MSYS the installer copies
# instead of linking, and `rm -f` cannot remove a directory.
# (Skip if you already ran the `rm -rf ~/.claude-deepseek` line above.)
rm -rf ~/.claude-deepseek/skills/surf-research-skill \
       ~/.claude-deepseek/skills/surf-plan-skill \
       ~/.claude-deepseek/skills/surf-free-skill
rm -rf ~/.config/surf            # ⚠ deletes your stored search / OpenRouter keys
npm config delete prefix         # only if installer 04 moved it to ~/.local
```

Then delete the `aula-dev` marked blocks from `~/.zshrc` / `~/.bashrc`. Ghostty itself is
removed with the package manager that installed it (`sudo apt remove ghostty`,
`sudo pacman -R ghostty`, `snap remove ghostty`, `brew uninstall --cask ghostty`, …), along
with the PPA or COPR repository it added if you want that gone too.

Deleting a local file does not revoke a credential: revoke the DeepSeek key at
<https://platform.deepseek.com/api_keys> and the search-provider keys at their own dashboards.

## Repository layout

```
vibe-engineer-tools/
├── README.md
├── LICENSE                  MIT
├── .gitignore
├── .gitattributes           eol=lf for .sh/.conf/.md/.js/.json + deepclaude/deepeco
│                            eol=crlf for .ps1
├── install.sh               orchestrator: 01 → 04, `./install.sh 01 03`, `--list`
├── 01-commands/             README.md · install.sh
│                            payload/{comandos.sh, projects-picker/}
├── 02-ghostty/              README.md · install.sh
│                            payload/{config.ghostty, themes/dracula}
├── 03-deepclaude/           README.md · install.sh · install.ps1
│                            payload/{deepclaude, deepclaude.ps1, deepeco, deepeco.ps1,
│                                     deepeco.conf, eco.md}
└── 04-agent-tools/          README.md · install.sh · install.ps1
```

**Why `.gitattributes` matters here.** Without the `eol=lf` rules, a clone on Windows with
`core.autocrlf=true` (the Git for Windows default) materializes the `.sh` and `.conf` files
with CRLF and bash dies with `$'\r': command not found` before printing anything useful. The
`.ps1` files go the other way — CRLF, native to PowerShell.

## Credits

**GitCraque** and **surf-skill** are independent projects by [Frederico
Kluser](https://github.com/frederico-kluser), both MIT, installed from npm and not vendored or
forked here — their own READMEs are the authority on their behaviour, and issues and stars
belong upstream. [Ghostty](https://ghostty.org/) is by Mitchell Hashimoto, with the official
[dracula/ghostty](https://github.com/dracula/ghostty) theme port and the
[nerd-fonts](https://github.com/ryanoasis/nerd-fonts) JetBrainsMono build; [Claude
Code](https://code.claude.com/docs) is by Anthropic and `deepclaude` launches the official
binary against a different backend rather than forking it;
[DeepSeek](https://api-docs.deepseek.com/) provides the Anthropic-compatible endpoint and the
models behind it; the picker's TUI is [Ink](https://github.com/vadimdemedes/ink).

Installers and class material: [frederico-kluser](https://github.com/frederico-kluser) for
[escola-mundo-dev](https://github.com/escola-mundo-dev) (Mundo Dev). Benchmarks, prices and
versions here were verified on **2026-08-18** and carry the date for a reason — every one of
them can move. `04-agent-tools` was verified end to end, and confirmed idempotent, in a
sandboxed `HOME` on that date.

## License

MIT © [escola-mundo-dev](https://github.com/escola-mundo-dev). See [LICENSE](LICENSE).
