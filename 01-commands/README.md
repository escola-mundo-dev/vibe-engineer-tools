# 01-commands — `up`, `qwe`, `projects`, `skills`

Four shell commands remove the friction between "I have a task" and "the agent is
working on it in an isolated branch".

| Command | What it does |
|---|---|
| `projects` | TUI picker (Ink/React) over **your** projects folder — newest first, type to filter, Enter opens, Esc cancels. The folder is asked for at install time and stored; change it any time with `projects --setup`. |
| `skills` / `s` | TUI picker (Ink/React) over your **agent-skills** folder (default `~/Agent-Skills`; configured with `skills --setup`, or override per-run with `SKILLS_DIR=/path skills`). Same picker as `projects`, pointed at skills. |
| `qwe [branch] [-a deepclaude\|claude]` | Creates a git worktree of the current repo at `<repo>.worktrees/<branch>`, cds into it, and — **only with `-a`** — launches the agent there. No branch given: it asks (Enter = `ai-task-<epoch>`). |
| `up` | From inside a worktree, back to the **main** repo root. From a subdirectory, back to the repo root. Outside git, up one level. |

## Your projects folder is a question, not a guess

There is **no default folder**. The installer asks for the absolute path of the directory
where *you* keep your repositories, and nothing is created in your home behind your back.

```bash
projects --setup     # (re)configure the folder, any time
projects --help
```

The prompt tells you how to find the path if you don't know it by heart — `pwd` inside the
folder from another terminal, or dragging the folder onto the terminal window (on Git Bash,
use the `/c/Users/you/...` form that `pwd` prints, not `C:\Users\you\...`). It accepts a
leading `~`, strips the quotes drag-and-drop leaves behind, offers to create the folder if it
does not exist yet, and stores the resolved physical path. Get it wrong, or change your mind
later, and `projects --setup` fixes it — the installer says so on its way out.

The answer lands in **`~/.config/aula-dev/projects.conf`**, deliberately a *separate* file
from `comandos.sh`: the installer overwrites `comandos.sh` on every run, and your
configuration must not die with it.

```ini
PROJECTS_DIR="/home/you/dev"
```

Resolution order is `$PROJECTS_DIR` (a one-off override: `PROJECTS_DIR=/tmp/x projects`)
then the config file. With neither, `projects` runs the setup instead of inventing a
directory, and `projects-picker` on its own exits `2` with the same instruction.

## Your agent-skills folder: a question, with a convenient default

`skills` rides the **same** Ink/React picker as `projects` (the picker is generic — it
takes `--root` and `--title`), but where projects has no default, skills ships one on
purpose: `~/Agent-Skills`, the agent-skills folder in your home. That is the one place
the machine already puts skills, so `skills` alone works out of the box.

It is still a question, not a fixed guess: you can point it elsewhere, and it remembers.

```bash
skills            # open the picker over ~/Agent-Skills (or your configured folder)
skills --setup    # tell it where *you* keep your agent-skills
skills --help
s                 # shorthand for skills
```

Resolution order is `$SKILLS_DIR` (a one-off override: `SKILLS_DIR=/tmp/skills skills`),
then `~/.config/aula-dev/skills.conf` (written by `skills --setup`, never by the
installer), then the default `~/Agent-Skills`. The conf mirrors `projects.conf` — read by
regex, never sourced:

```ini
SKILLS_DIR="/home/you/agent-skills"
```

`SKILLS_CONF` points the lookup at another file, just like `PROJECTS_CONF` does.

## Install

```bash
./install.sh
```

- **Linux / macOS:** run it in your terminal.
- **Windows:** run it inside **Git Bash** (ships with Git for Windows:
  `winget install --id Git.Git -e`). Plain PowerShell cannot execute `.sh`.

The installer is idempotent — running it twice duplicates nothing — and it guarantees
Node.js ≥ 18 on its own (brew on macOS, nvm on Linux, winget on Git Bash).

> The installer's own terminal output is in Portuguese. The commands themselves are
> language-neutral.

## Design notes worth knowing

**The picker writes its UI to stderr.** `render(<App/>, {stdout: process.stderr})` — so
stdout carries exactly one thing: the chosen path, written with `fs.writeSync(1, path)`.
That is what lets the shell function do `cd "$(projects-picker)"` without swallowing the
interface. It is the same convention `fzf` uses. `projects-picker --list` prints the names
with no TUI at all, which is how the installer smoke-tests itself.

**The picker is a generic Ink/React TUI, reused by `projects` and `skills`.** It accepts
`--root <dir>` (win over `$PROJECTS_DIR` and the conf) and `--title <text>` (header text,
default "Escolha um projeto"). `projects` calls it with the resolved folder via
`PROJECTS_DIR`; `skills` calls it explicitly as `projects-picker --root "$dir" --title
"Escolha uma skill"`. Unknown flags are ignored, and `--list` prints only names with no TUI.

**React is pinned at 18.3.1 on purpose.** `ink` 5.2.1 depends on `react-reconciler` built
against the React 18 ABI; on React 19 the app throws at runtime. Do not bump one without
the other. The installer uses `npm ci`, never `npm install`, so the lockfile is the source
of truth.

**`qwe` resolves the account before it creates anything.** An unknown account fails while
the tree is still clean, so you never end up with an orphan branch and directory. It also
records where the branch came from:

```bash
git config branch.<branch>.origdir      # the main repo root
git config branch.<branch>.origbranch   # the branch you were on
```

There is no teardown command by design — closing a worktree is a conscious act:

```bash
git merge <branch>                                   # or: git branch -D <branch>
git worktree remove ../<repo>.worktrees/<branch>
```

**`up` uses the first entry of `git worktree list --porcelain`**, which git guarantees is
the main worktree — not `--git-common-dir`, which returns a *relative* path when you are in
a subdirectory. Both sides are normalized through `cd` + `pwd -P`, because Git Bash prints
`C:/Users/...` while `$PWD` is `/c/Users/...`, and on macOS a symlinked cwd (`/tmp` →
`/private/tmp`) never compares equal to the physical path.

## What it puts on your machine

| Path | What |
|---|---|
| `~/.local/share/projects-picker/` | the picker app + `node_modules` (exact lockfile deps) |
| `~/.local/bin/projects-picker` | symlink (Linux/macOS) or wrapper script (Git Bash) |
| `~/.config/aula-dev/comandos.sh` | the `up`/`qwe`/`projects`/`skills` functions — portable across zsh **and** bash (**overwritten on every install**) |
| `~/.config/aula-dev/projects.conf` | your projects folder — written by `projects --setup`, never overwritten by the installer |
| `~/.config/aula-dev/skills.conf` | your agent-skills folder — written by `skills --setup`, never overwritten by the installer |
| `~/.zshrc` / `~/.bashrc` | one marked block: `>>> aula-dev … <<<` |

## Uninstall

```bash
rm -rf ~/.local/share/projects-picker ~/.local/bin/projects-picker \
       ~/.config/aula-dev/comandos.sh ~/.config/aula-dev/projects.conf \
       ~/.config/aula-dev/skills.conf
# then delete the ">>> aula-dev" block from ~/.zshrc / ~/.bashrc
```
