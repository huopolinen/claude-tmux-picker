# claude-tmux-picker

An interactive **tmux session picker for [Claude Code](https://claude.com/claude-code) running on a remote server.**

If you run Claude Code on a box you SSH into, you probably keep several
long-lived agents alive in separate `tmux` sessions — one per project. The
problem on every reconnect: *which session was which, and which one is sitting
there waiting for my answer?*

This drops an `fzf` menu in front of you the moment you SSH in:

```
tmux >
  ↑/↓ move · Enter choose · Esc skip · ★ = waiting for you
┌──────────────────────────────┬────────────────────────────────────────────┐
│ landing   ★ waiting for you   │  ❯ Посмотри что там долили? Можно            │
│ systema   ★ waiting for you   │     продолжать или ещё подождать?            │
│ claude    · working…          │  ──────────────────────────────────────     │
│ main      · working… (attached)│    ⏵⏵ bypass permissions on (shift+tab)     │
│ ＋ create a NEW session       │                                              │
│ ✗ skip (plain shell)          │   ← live preview of the highlighted session  │
└──────────────────────────────┴────────────────────────────────────────────┘
```

## What it does

- **Lists every tmux session** with a live preview of its tail in the right
  half of the screen, so you can see what each agent is up to before attaching.
- **Flags sessions waiting for you with `★`.** A Claude turn that is still
  running shows `esc to interrupt` in its status line; when that's gone, the
  agent is idle or asking you something. Those sessions sort to the top.
- **Refreshes itself live** (every 2s by default) — the `★` flags, the
  ordering and the previews stay current while the menu is open, without
  losing your place in the list. An agent that finishes a turn pops to the
  top while you're looking at it.
- **Create a new session** that launches Claude Code in your home directory
  (`claude --dangerously-skip-permissions` by default).
- **Skip** to a plain shell, or just hit `Esc`.
- Arrow keys to move, type to filter, `Enter` to attach.

It only activates for **interactive SSH shells that aren't already inside
tmux**, so local shells and nested panes are left alone.

## Requirements

- `tmux`
- [`fzf`](https://github.com/junegunn/fzf) (`apt install fzf`, `brew install fzf`, …)
- Bash

## Install

```bash
git clone https://github.com/huopolinen/claude-tmux-picker.git ~/claude-tmux-picker
chmod +x ~/claude-tmux-picker/*.sh
echo 'source ~/claude-tmux-picker/claude-tmux-picker.sh' >> ~/.bashrc
```

Reconnect (or `source ~/.bashrc` in a non-tmux SSH shell) and the picker appears.

## Configuration

Export these **before** the `source` line in `~/.bashrc` to override defaults:

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_TMUX_NEW_CMD` | `claude --dangerously-skip-permissions` | command a brand-new session runs |
| `CLAUDE_TMUX_DEFAULT` | `main` | default name offered for a new session |
| `CLAUDE_TMUX_REFRESH` | `2` | seconds between live refreshes of the list and preview |
| `CLAUDE_TMUX_PREVIEW` | next to the script | path to the preview helper |
| `CLAUDE_TMUX_LIST` | next to the script | path to the list-generator helper |

Example — start new sessions in a plain shell instead of Claude:

```bash
export CLAUDE_TMUX_NEW_CMD=''   # empty = just a shell
source ~/claude-tmux-picker/claude-tmux-picker.sh
```

## How the "waiting" detection works

The picker captures each session's pane and greps for `esc to interrupt`,
the marker Claude Code shows only while a turn is actively running. Present →
`· working…`. Absent → `★ waiting for you`. It's a heuristic tuned for the
Claude Code TUI, not a formal API, but in practice it reliably tells a busy
agent from one that needs you.

## License

MIT
