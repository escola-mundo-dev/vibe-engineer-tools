# 01-commands — `up`, `qwe`, `projects`

Three shell commands that remove the friction between "I have a task" and "the agent is
working on it in an isolated branch".

| Command | What it does |
|---|---|
| `projects` | TUI picker (Ink/React) for the directories in `~/Projects` — newest first, type to filter, Enter opens, Esc cancels. Projects live elsewhere? `export PROJECTS_DIR=/path`. |
| `qwe [branch] [-a deepclaude\|claude]` | Creates a git worktree of the current repo at `<repo>.worktrees/<branch>`, cds into it, and — **only with `-a`** — launches the agent there. No branch given: it asks (Enter = `ai-task-<epoch>`). |
| `up` | From inside a worktree, back to the **main** repo root. From a subdirectory, back to the repo root. Outside git, up one level. |

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
| `~/.config/aula-dev/comandos.sh` | the three functions — portable across zsh **and** bash |
| `~/.zshrc` / `~/.bashrc` | one marked block: `>>> aula-dev … <<<` |

## Uninstall

```bash
rm -rf ~/.local/share/projects-picker ~/.local/bin/projects-picker \
       ~/.config/aula-dev/comandos.sh
# then delete the ">>> aula-dev" block from ~/.zshrc / ~/.bashrc
```
