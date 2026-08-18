# 02-ghostty — the terminal, configured for agent streaming

Installs [Ghostty](https://ghostty.org) and writes the class configuration: Dracula theme
(the official `dracula/ghostty` port), JetBrainsMono Nerd Font, tabs in the titlebar,
splits on `Ctrl`+arrows, a 100 MB scrollback for long agent sessions, and two deliberate
performance guards.

## Install

```bash
./install.sh
```

| System | Route |
|---|---|
| Ubuntu / Pop!\_OS / Mint | PPA `mkasberg/ghostty-ubuntu` |
| Arch | `pacman` |
| Fedora / RHEL | `dnf copr enable pgdev/ghostty` (installs `dnf-plugins-core` first — Server and minimal images ship without the `copr` plugin) |
| openSUSE | `zypper` |
| Anything else | `snap install ghostty --classic`, or the official binary guide |
| macOS | `brew install --cask ghostty` |
| Windows | **No official build (August 2026).** The script explains the two routes and exits cleanly: WSL2 (recommended — run this same `install.sh` inside it) or the community port [winghostty](https://winghostty.com/) |

> The installer's own terminal output is in Portuguese.

## The three rules that will save you an hour

**1. Ghostty has no config watch — applying a change means reloading.**
Issue [#449](https://github.com/ghostty-org/ghostty/issues/449) was closed `wontfix`.
Save the file, then `Ctrl+Shift+,` in a Ghostty window, or signal it without opening one:

```bash
kill -USR2 $(pgrep -x ghostty)
```

Never kill and relaunch the app "to apply config". With `gtk-single-instance = true`,
running `ghostty` again does not re-read the file — the new process hands the window to the
existing one, which still holds the old config in memory.

**2. Validate before you reload.**

```bash
ghostty +validate-config --config-file=/absolute/path/to/config.ghostty
```

The syntax is exact: `--config-file=` **with the `=`**, and an **absolute** path. The
space-separated form and the `~/...` form both exit 1 *silently*. Exit 0 with no warnings
means you are good; a bad key is reported as `unknown field` with its line number.

**3. Some keys only take effect in a new window.**
`gtk-titlebar-style` and `window-theme` are window-creation values — reload, then open a
new window. `gtk-single-instance` is read once at process start, so it needs a real restart.

Inspect what is actually live: `ghostty +show-config` · `ghostty +list-keybinds` ·
`ghostty +list-themes`. Note that `ghostty +list-config` **does not exist** in 1.3.1.

## Keys this config binds

| Keys | Action |
|---|---|
| `Ctrl+T` | new tab |
| `Ctrl+R` | rename tab |
| `Ctrl+←/→/↑/↓` | new split in that direction |
| `Ctrl+Alt+arrows` | move between splits (Ghostty default) |
| `Ctrl+8/4/2/6` | resize the divider up / left / down / right |
| `Ctrl+W` | close surface (guarded by `confirm-close-surface`) |
| `Ctrl+Shift+,` | reload config |

These **take keys away from zsh**: `Ctrl+R` (reverse search), `Ctrl+W`
(backward-kill-word) and `Ctrl+`arrows (word jump) now belong to the terminal. That is a
deliberate trade — remove the `keybind` lines you don't want and reload.

## Settings with a story behind them

- **`scrollback-limit = 100000000` — the unit is BYTES, not lines.** The 1.3.x default is
  `10000000` (10 MB). 100 MB gives an order of magnitude of headroom for a long agent
  session; allocation is lazy and the buffer is a ring, so it only consumes what was
  actually printed. Setting `1000000` would be *smaller* than the default and would
  truncate a session in minutes.
- **`background-opacity = 1.0`** — no per-frame alpha compositing. A GPU terminal was once
  measured at 936% CPU on a presentation path with transparency; this is the guard.
- **`cursor-style-blink = false`** — a blinking cursor wakes the redraw loop about twice a
  second for nothing. The key name matters: **`cursor-blink` does not exist** in 1.3.1 and
  is rejected as `unknown field`.
- **`theme = dracula`** — the official [dracula/ghostty](https://github.com/dracula/ghostty)
  port, installed to `~/.config/ghostty/themes/dracula`. The **built-in `Dracula`**
  (capital D) is a *different* theme with different colors.

## What it puts on your machine

- `~/.config/ghostty/config.ghostty` — the config. An existing one is backed up to
  `.bak-<timestamp>` first; nothing is ever deleted.
- `~/.config/ghostty/themes/dracula` — the theme.
- `~/.local/share/fonts/` — the font, if it was missing.
- `shell-integration` is rewritten to match your login shell (bash / fish / zsh).

**A legacy `config` file is moved aside.** Since 1.2.3 the canonical name is
`config.ghostty`; a pre-1.2.3 `config` is still read, the two are *merged*, and on conflict
the old `config` **wins** — it would silently override the keys installed here. The
installer renames it to `config.pre-aula-bak-<timestamp>` rather than deleting it.
