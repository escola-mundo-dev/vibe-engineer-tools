# vibe-engineer-tools

The terminal setup used in the **Mundo Dev** class on AI-assisted development: four
idempotent installers that give you a project picker, disposable git worktrees, a terminal
tuned for agent output, Claude Code running on a DeepSeek brain, and two companion pieces —
**GitCraque** (a desktop Git client with no Electron) and **deep-orchestrator** (an
autonomous multi-agent orchestrator skill for Claude Code).

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
       └─ "orquestre essa tarefa"      deep-orchestrator: waves + isolated worktrees
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
| [`04-agent-tools`](04-agent-tools/) | `gitcraque` from npm, the `deep-orchestrator` skill | `gitcraque`, `/deep-orchestrator` |

Each folder has its own README with the same material at reference depth. Two of the tools
are **separate open-source projects by the same author**, brought in rather than vendored
here — file issues and stars upstream:

| Project | Repo | Installed as | License |
|---|---|---|---|
| **GitCraque** | [frederico-kluser/GitCraque](https://github.com/frederico-kluser/GitCraque) | npm package `gitcraque` | MIT |
| **deep-orchestrator** | [frederico-kluser/deep-orchestrator](https://github.com/frederico-kluser/deep-orchestrator) | Claude Code skill, cloned by installer 04 (v3.4.0) | MIT |

## Contents

- [Before you install](#before-you-install)
- [Install](#install)
- **The journey** — one task, end to end
  - [Stop 0 — the window you watch it on (Ghostty)](#stop-0--the-window-you-watch-it-on-ghostty)
  - [Stop 1 — land in the repo (projects)](#stop-1--land-in-the-repo-projects)
  - [Stop 2 — an isolated place to work (qwe)](#stop-2--an-isolated-place-to-work-qwe)
  - [Stop 3 — the agent (deepclaude)](#stop-3--the-agent-deepclaude)
  - [Stop 4 — the agent orchestrates itself (deep-orchestrator)](#stop-4--the-agent-orchestrates-itself-deep-orchestrator)
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
| Node.js | 01 only | `01-commands` installs it: Homebrew on macOS (**and fails if Homebrew is absent** — <https://brew.sh>), `nvm` v0.40.6 + `nvm install 24` on Linux, `winget OpenJS.NodeJS.LTS` on Git Bash |
| **Node.js ≥ 22.13** | GitCraque only (from 04) | `04-agent-tools` **skips GitCraque with a warning** and still installs the deep-orchestrator skill — it needs **no Node at all**. `nvm install 24`, then re-run `./install.sh 04` |
| `sudo` + a supported package manager | 02 on Linux | `apt` (with the `mkasberg/ghostty-ubuntu` PPA), `pacman`, `dnf copr`, `zypper`, or `snap`. On an unrecognized distro with no snap, the script stops and points at <https://ghostty.org/docs/install/binary> |
| `unzip` or `tar`, plus fontconfig | 02 on Linux | to unpack and register JetBrainsMono Nerd Font (`fc-cache`, `fc-list`) |
| A funded **DeepSeek** account | 03 | create a key at <https://platform.deepseek.com/api_keys> — the installer validates it before storing it |

**On a machine with no Node at all, the full run legitimately takes two passes.** This is
not a bug and the scripts say so, in Portuguese:

- **Git Bash:** `01-commands` installs Node through `winget`, prints *"FECHE e REABRA o Git
  Bash"* and exits 0. Close the window, open a new one, run `./install.sh` again.
- **Linux:** `01-commands` installs Node through `nvm` **inside its own subshell**, so the
  parent run's `PATH` never sees it. Installer 04 no longer needs Node for itself: the
  deep-orchestrator skill installs anyway and only **GitCraque is skipped**. Open a new
  terminal and run `./install.sh 04` again to get GitCraque.

## Install

```bash
git clone https://github.com/escola-mundo-dev/vibe-engineer-tools.git
cd vibe-engineer-tools
./install.sh
```

That runs `01 → 02 → 03 → 04` in order. **The order matters**: `01-commands` is what
installs Node.js, and `04-agent-tools` needs it for GitCraque.

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

GitCraque publishes a **Linux and macOS** platform badge; `04-agent-tools` will still
install the npm package on Windows, and its only stated requirements are Node ≥ 22.13 and
`git` on your `PATH`. The deep-orchestrator skill needs **no Node at all** — just git and a
Claude Code install. Installers 01 and 02 are shell-only by design.

### Then open a new terminal

The installers append a marked block to your `~/.zshrc` and/or `~/.bashrc`, which the
session you installed from does not have. Open a new terminal (or `source ~/.zshrc`) and
check:

```bash
type qwe up projects                 # the three functions are loaded
projects-picker --list               # the TUI's non-interactive mode
deepeco                              # peak/off-peak status + price table
gitcraque --version
ls -l ~/.claude-deepseek/skills/deep-orchestrator   # the skill must be bridged in here
```

That last line is the one worth checking: if those links are missing, `deepclaude` cannot
see the skill — see [Stop 4](#stop-4--the-agent-orchestrates-itself-deep-orchestrator). A
search smoke test lives at
`~/.local/share/deep-orchestrator/scripts/check-search-credits.sh`, and the plan gate's
installer at `~/.local/share/deep-orchestrator/scripts/check-plannotator.sh`.

---

# The journey

One real task, end to end: *add rate limiting to an Express API*. Each stop introduces the
tool that serves it, with install and configuration inline.

## Stop 0 — the window you watch it on (Ghostty)

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
# the installer asks for YOUR projects folder on its way out, then open a NEW
# terminal — `projects` is a shell function, and the installer runs in a child
# process that cannot define functions in your current shell
projects
```

**The folder is asked for, never assumed.** There is no default and nothing is created in
your home: the installer prompts for the absolute path of the directory where *you* keep
your repositories, and tells you how to find it if you don't know it by heart — run `pwd`
inside the folder from another terminal, or drag the folder onto the terminal window. (On
Git Bash use the `/c/Users/you/...` form `pwd` prints, not `C:\Users\you\...`.) Answer
wrong, or move your repos later, and one command fixes it:

```bash
projects --setup     # (re)configure the folder, any time
projects --help
```

The answer goes to **`~/.config/aula-dev/projects.conf`** — a *separate* file from
`comandos.sh` on purpose, because the installer overwrites `comandos.sh` on every run and
your configuration must survive that. Resolution order is `$PROJECTS_DIR` (a one-off
override: `PROJECTS_DIR=/srv/code projects`) then the config file; with neither, `projects`
runs the setup rather than inventing a directory.

A TUI (Ink 5.2.1 + React 18.3.1) then lists the directories in that folder, newest-modified
first with a relative-time hint. Type to filter, `↑↓` through a 10-item sliding window,
`Enter` to open, `Esc` or `Ctrl+C` to cancel without moving.

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
cd ~/dev/my-api
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
| `thinking.budget_tokens` | Accepted, then **ignored** — DeepSeek uses a qualitative `reasoning_effort`. Can appear as `API Error: 400 thinking options type cannot be disabled when reasoning_effort is set`. |
| Parallel tool calls | Often **serialize** in practice: lower cost, higher wall-clock. |
| `code_execution_tool_result`, `container*` | Unsupported. |
| `web_search_tool_result` | **Still works** — routed to DeepSeek's own engine. |

Two risks that are not feature-shaped. **Hallucination**: V4 Pro scored a 94% hallucination
propensity on AA-Omniscience, so treat confident factual claims from this stack as unverified
by default — inside an agent loop an invented package name becomes a real install attempt and
a real rabbit hole. Precisely why [Stop 4](#stop-4--the-agent-orchestrates-itself-deep-orchestrator)
exists: an agent that plans, delegates to isolated worktrees and reviews adversarially
instead of winging it. **Data retention**: sending proprietary code to public DeepSeek infrastructure means
you no longer have Anthropic's zero-data-retention guarantees. Know your employer's policy
before you point `qwe -a deepclaude` at a work repo; that is a decision for a human, not for
a shell script.

Known workaround for the "tool call black hole" — the agent reports edits, the disk
disagrees:

```bash
export CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING=0
```

## Stop 4 — the agent orchestrates itself (deep-orchestrator)

You ask for rate limiting on Express. The model answers from training data, and
`express-rate-limit` changed its options object after that data was collected. This is the
failure mode that costs the most time, because the output *looks* right.

**deep-orchestrator** is a **Claude Code skill** (no binary, no npm package): an autonomous
multi-agent orchestrator. It never writes code itself — it plans, splits the task into
**waves** (unlimited, with the plan recalculated dynamically after each wave by a PLAN
REVISER sub-agent), creates a **named, isolated git worktree per sub-agent**, delegates each
wave in parallel, applies **adversarial review**, integrates every result via **squash-merge
one at a time** — the gate (build + tests + linter) runs against an **integration snapshot**
in an ephemeral `int-ondaN-*` worktree, outside the critical path — removes worktree, branch
and intermediate commits at the end of each wave, and commits everything at the end
**without asking the user anything**. Asynchronous **testing** and **validation** subwaves
(`test-ondaN-*`, `val-ondaN-*`) run after each wave.
<https://github.com/frederico-kluser/deep-orchestrator> · MIT, v3.4.0.

```
ANALYZE → PLAN → EXECUTE-ONDA (repeat, until the reviser declares convergence) → COMMIT-FINAL
```

The class example — *add rate limiting to an Express API* — becomes an orchestration of two
or more waves, each with its own named worktrees (a config wave, an implementation wave, a
testing wave), and the history on your branch ends up as one squash commit per sub-agent
plus a final commit. Worktrees and branches are gone by the end.

### Contained mode is the point

The skill respects the boundary the rest of this repo is built around. Invoked inside a git
**worktree** — exactly the kind `qwe` creates — it enters **contained mode**: that worktree
is its *root of the world*. It integrates into the worktree's own branch, **never**
`main`/`master`, and never writes a single file into the main project. `qwe` gives the task
an isolated room; deep-orchestrator works inside that room and cleans up after itself.

### Install, and the bridge that makes it visible

```bash
./install.sh 04
```

That clones the skill into `~/.local/share/deep-orchestrator/` (set `DEEP_ORCHESTRATOR_SRC`
to a local path or another URL to use your own copy) and then does the thing this repo
exists to do. `deepclaude` runs Claude Code with `CLAUDE_CONFIG_DIR=~/.claude-deepseek`, and
personal skills are read from `<CLAUDE_CONFIG_DIR>/skills`. So the installer bridges the
skill — `SKILL.md` + `scripts/` + `prompts/` + `templates/` — into `~/.claude/skills/` for
the main harness **and** into `~/.claude-deepseek/skills/` for `deepclaude` (a copy on
MSYS/Git Bash without symlink privileges; the PowerShell installer tries a junction first,
which needs no admin rights). A **real directory** at one of those paths is left alone with
a warning. The bridge resolves against the clone, so if the skill's home moves later,
re-run this installer to refresh the links.

It also handles the other silent failure of `npm i -g`: if the global npm prefix is not
writable by your user (distro-packaged Node writing to `/usr/lib/node_modules`) it does
**not** reach for `sudo`, which would install for root and disappear from your `PATH`. It
runs `npm config set prefix ~/.local` instead — a global npm setting, so every future
`npm i -g` lands there too, next to everything else this repo installs.

**No Node is required** — on a machine with no Node at all, the skill installs fine; only
GitCraque is skipped (its floor is 22.13, [Stop 5](#stop-5--read-the-history-gitcraque)).

### Configure: the Brave key wizard (optional)

The installer offers the wizard at the end; skipping is safe — search degrades gracefully,
it is never a hard blocker. The wizard asks for a **Brave Search API key**
(<https://api.search.brave.com/app/keys>), **validates it live** (an invalid key is not
saved), writes it to `~/.config/aula-dev/brave.key` (mode 600) and exports it from your rc
(a marked `BRAVE_API_KEY` block, added idempotently).

The orchestrator checks its search tiers before every wave
(`scripts/check-search-credits.sh`) and falls back through a four-tier chain:

| Tier | Backend | Key needed? |
|---|---|---|
| 0 | the harness's own web search (in Claude Code: `WebSearch`/`WebFetch`) | no — no key, no script |
| 1 | the legacy AI-powered search skill — **no longer installed by this repo**; used automatically only if the machine still has an old installation | no |
| 2 | Brave Search API | the wizard's key (optional) |
| 3 | DuckDuckGo keyless (Instant Answer, limited coverage) | no — always works |

**Nothing is a hard blocker.** Without a Brave key the search degrades to the harness's
native search (Tier 0) and/or the keyless tier (Tier 3) — degraded but operational — and
`check-search-credits.sh` exits `1`, which is **expected and fine** (it means "keyless
only", not "broken"). Two notes on Tier 2: the Brave model has been **metered since
February 2026** — monthly credits, charged above the quota — so the pre-wave credit check
is also **financial** protection; and installer 04 no longer installs the Tier-1 skill, so
on a fresh machine the orchestrator searches through tiers 0/2/3 — with the Brave key
(recommended, via the wizard) or keyless.

### Use it

Inside the `deepclaude` session from Stop 3, standing in a project — or inside a `qwe`
worktree, which switches on contained mode:

```bash
/deep-orchestrator add rate limiting to the Express API, with a configurable window
/deep-orchestrator max-parallel=4 <task>   # optional prefix: cap parallelism (default 20)
/deep-orchestrator plan=on <task>          # optional prefix: force the plan-approval gate
/deep-orchestrator plan=off make a plan and run it   # force full autonomy
```

Trigger phrases: *"orquestre isso"*, *"resolva do início ao fim"*, *"não me pergunte nada"*,
*"toca o barco"*. The agent does not just execute — it organizes itself into waves with
isolated, named worktrees, tests and validates what it built, and commits when done. Don't
use it for trivial one-line edits: that is what a plain session is for.

### The plan-approval gate (Plannotator)

Most invocations are fully autonomous, but when you **ask for a plan** the orchestrator
stops at **Phase 2.5** and sends the plan to the
[Plannotator](https://github.com/backnotprop/plannotator) in your browser. You **approve or
annotate** it there; every annotation **regenerates the plan and opens a brand-new
Plannotator** (new process, new server, new tab) — up to a revision budget of 5 — and
**no worktree, branch or commit exists before the plan is approved**. If the gate ends
without approval, nothing was built and the repository is exactly as it was.

How it turns on: the `plan=on` prefix always wins; natural-language triggers like
*"faça um plano"*, *"planeje"*, *"quero aprovar antes"* turn it on too; `plan=off` forces
full autonomy. With no prefix and no trigger the default is **off — no browser ever opens
unless you asked for a plan**. The orchestrator installs the Plannotator itself when it is
missing (`check-plannotator.sh --install`): just the binary in `~/.local/bin` (minimum
0.19.1), no `sudo`, no `npm -g`. The verdict comes from the exit code — 0 approved · 10
annotated · 11 closed · 12 timeout · **13 tool failure** · 14 budget exhausted — the plan title is immutable
between revisions, the server stays on `127.0.0.1` with external sharing off, and
reviewing over SSH requires a tunnel.

### Security

The orchestrator delegates to sub-agents that run commands on your machine, each inside its
own disposable worktree, and its web search feeds page content to them. Search results are
untrusted data — the prompts say so, but treat a cited answer like any web-sourced claim.
Contained mode confines writes to your worktree; the branch is still yours to review with
GitCraque before you `up` and merge.

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
cd ~/dev/my-api && gitcraque
npx gitcraque                       # or no install at all
```

**Node ≥ 22.13 and `git` on your `PATH`. Linux and macOS.** The floor is not arbitrary: the
project memory uses `node:sqlite`, which only drops the `--experimental-sqlite` flag at
22.13. The installer checks that floor separately from the deep-orchestrator skill, which
needs **no Node at all**; if your Node is older, **GitCraque is skipped with a warning
instead of failing the run** — you still get deep-orchestrator. Raise Node
(`nvm install 24`) and re-run `./install.sh 04`; it is idempotent.

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
| `~/.local/bin/plannotator` | the plan gate's binary — installed on demand by the skill (`check-plannotator.sh --install`; only the binary, no `sudo`/`npm -g`) |
| `~/.local/share/projects-picker/` | the TUI and its `node_modules` |
| `~/.local/share/deep-orchestrator/` | the skill's home — the clone (`SKILL.md`, `scripts/`, `prompts/`, `templates/`) |
| `~/.local/share/fonts/JetBrainsMonoNerdFont/` | the Nerd Font, on Linux, if it was missing |
| `~/.config/aula-dev/comandos.sh` | `projects`, `qwe`, `up` |
| `~/.config/aula-dev/deepeco.conf` | peak/off-peak windows and prices |
| `~/.config/aula-dev/brave.key` | optional Brave Search API key (mode 600) |
| `~/.config/ghostty/config.ghostty` | terminal config (+ `themes/dracula`, + any `.bak-*`) |
| `~/.claude-deepseek/` | isolated Claude Code config (mode 700) |
| `~/.claude-deepseek/deepseek.key` | your DeepSeek key (mode 600) |
| `~/.claude-deepseek/commands/eco.md` | the `/eco` slash command |
| `~/.claude/skills/deep-orchestrator` + `~/.claude-deepseek/skills/deep-orchestrator` | the skill, bridged in for the main harness and for `deepclaude` |
| `~/.config/aula-dev/projects.conf` | **your** projects folder — written by `projects --setup`; the installer never overwrites it, and no projects folder is ever created for you |
| `~/.zshrc` / `~/.bashrc` | one marked block per concern, added idempotently |

The rc blocks are delimited by `# >>> aula-dev (...) >>>` / `# <<< aula-dev (...) <<<` —
`comandos da aula` from installer 01, `PATH ~/.local/bin` from 03, `PATH npm global` from 04
when the npm bin directory is somewhere other than `~/.local/bin`, and `BRAVE_API_KEY` from
04 when the Brave key wizard was used. Deleting a block cleanly
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
| `projects` · `projects --setup` · `projects --help` | TUI picker over your configured folder, then `cd`; `--setup` (re)configures which folder that is |
| `qwe [branch] [-a deepclaude\|claude]` | sibling worktree, enter it, optionally launch an agent |
| `up` | worktree → main repo root; subdir → repo root; otherwise `cd ..` |
| `deepclaude [claude args]` · `--pro` · `--setup-key` · `--help` | Claude Code on V4 Flash · session on V4 Pro · key setup |
| `deepeco` · `--short` · `--help` · `/eco` | peak/off-peak status + price table; `--short` is what `deepclaude` prints at launch, `/eco` is the in-session version |
| `gitcraque [path]` · `--repo` · `--port` · `--no-open` | the Git client, in your browser, on 127.0.0.1 |
| `/deep-orchestrator <task>` · `plan=on|off` · `max-parallel=N` | autonomous multi-agent orchestration: waves, named worktrees, squash-merge, final commit — `plan=on` gates the plan through the Plannotator first |

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
| `04-agent-tools` skipped GitCraque (no Node, or Node < 22.13) | Expected on a fresh machine: `01` installs Node with `nvm` inside its own subshell, so the parent run never sees it — or Node is older than 22.13. The deep-orchestrator skill installed anyway. Open a new terminal and run `./install.sh 04` to get GitCraque. |
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
| The agent cannot see the deep-orchestrator skill | The bridge into `~/.claude-deepseek/skills/` did not run, or a real directory sits at that path. Re-run `./install.sh 04` and read the warnings. |
| `check-search-credits.sh` exits 1 — search degraded | No Brave key: only the harness's native search and the keyless tier are available. **Expected, exit 1 is fine** — search stays operational, just limited. Re-run `./install.sh 04` and take the key wizard for full search. |
| `plan=on` never opens a browser | The gate only turns on via the `plan=on` prefix or a plan trigger (*"faça um plano"*, *"quero aprovar antes"*); with neither, the default is **off** — nothing opens unless you asked for a plan. |
| deep-orchestrator does not appear in `deepclaude` | Re-run `./install.sh 04` — bridging into `~/.claude-deepseek/skills/` is part of it. |
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
npm rm -g gitcraque
# The deep-orchestrator skill: two bridges plus the cloned home.
# -rf, not -f: on Windows/MSYS the installer copies instead of linking,
# and `rm -f` cannot remove a directory.
rm -rf ~/.claude/skills/deep-orchestrator \
       ~/.claude-deepseek/skills/deep-orchestrator \
       ~/.local/share/deep-orchestrator
rm -f  ~/.config/aula-dev/brave.key    # only if you ran the Brave key wizard
npm config delete prefix               # only if installer 04 moved it to ~/.local
```

Machines that used an older version of this repo may still carry the legacy npm search
skill. Remove it by hand if you want it gone — `npm rm -g` its package, its skill
directories under `~/.claude/skills`, `~/.claude-deepseek/skills` and the other harness
skill folders it symlinked into, and its keys directory under `~/.config`; without it the
orchestrator's search simply uses its remaining tiers.

Then delete the `aula-dev` marked blocks from `~/.zshrc` / `~/.bashrc`. Ghostty itself is
removed with the package manager that installed it (`sudo apt remove ghostty`,
`sudo pacman -R ghostty`, `snap remove ghostty`, `brew uninstall --cask ghostty`, …), along
with the PPA or COPR repository it added if you want that gone too.

Deleting a local file does not revoke a credential: revoke the DeepSeek key at
<https://platform.deepseek.com/api_keys> and the Brave key at
<https://api.search.brave.com/app/keys>.

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

**GitCraque** (an npm package) and **deep-orchestrator** (a Claude Code skill) are
independent projects by [Frederico Kluser](https://github.com/frederico-kluser), both MIT —
GitCraque from npm, the skill cloned by installer 04 — not vendored or forked here: their
own READMEs are the authority on their behaviour, and issues and stars belong upstream. [Ghostty](https://ghostty.org/) is by Mitchell Hashimoto, with the official
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
